import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ClipboardStore {
    private(set) var items: [ClipboardItem] = []
    private(set) var visibleItems: [ClipboardItem] = []
    private(set) var visibleItemsRevision = 0
    private(set) var pinnedItemCount = 0
    var selectedItemID: ClipboardItem.ID?
    var searchQuery: String = "" {
        didSet { rebuildVisibleItems() }
    }
    var selectedFilter: ClipboardFilter = .all {
        didSet { rebuildVisibleItems() }
    }
    var storageMessage: String?
    private(set) var syncState: ClipSyncState = .idle

    private let historyStore: EncryptedHistoryStore
    private let syncDefaults: UserDefaults
    private let syncService: ClipSyncService?
    private var policy: ClipboardHistoryPolicy
    private var persistTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var syncRequestedWhileSyncing = false
    private var syncMetadata: ClipSyncMetadata
    private var isApplyingSync = false
    private let syncMetadataKey = "clippa.sync.metadata"

    init(
        historyStore: EncryptedHistoryStore = EncryptedHistoryStore(),
        policy: ClipboardHistoryPolicy = .default,
        syncDefaults: UserDefaults = .standard,
        syncService: ClipSyncService? = nil
    ) {
        self.historyStore = historyStore
        self.policy = policy
        self.syncDefaults = syncDefaults
        self.syncService = syncService
        if let data = syncDefaults.data(forKey: syncMetadataKey),
           let metadata = try? JSONDecoder().decode(ClipSyncMetadata.self, from: data) {
            self.syncMetadata = metadata
        } else {
            self.syncMetadata = ClipSyncMetadata()
        }
    }

    func load() async {
        do {
            let snapshot = try await historyStore.load()
            let repairs = snapshot.items.map { item in
                (original: item, repaired: item.repairedForCurrentVersion)
            }
            let contentMigrations = repairs.filter { $0.original.id != $0.repaired.id }
            let migrationDate = Date()
            contentMigrations.forEach { migration in
                markDeleted(migration.original)
                markChanged(migration.repaired, at: migrationDate)
            }
            items = ordered(repairs.map(\.repaired))
            let removed = enforceRetention(now: migrationDate)
            removed.forEach(markDeleted)
            rebuildVisibleItems()
            if repairs.contains(where: { $0.original != $0.repaired }) || !removed.isEmpty {
                persist(.immediate)
            }
        } catch EncryptedHistoryStoreError.corruptStoreIsolated(let url) {
            items = []
            rebuildVisibleItems()
            storageMessage = String(localized: "Encrypted history was reset because the local store was damaged. The damaged file was isolated at \(url.lastPathComponent).")
        } catch {
            items = []
            rebuildVisibleItems()
            storageMessage = String(localized: "Encrypted history could not be loaded. A clean history is active.")
        }
    }

    func add(payload: ClipboardPayload, sourceBundleIdentifier: String?, date: Date = Date()) {
        let hash = payload.stableHash
        if let index = items.firstIndex(where: { $0.payloadHash == hash }) {
            items[index].lastUsedAt = date
            items[index].createdAt = date
            items[index].sourceBundleIdentifier = sourceBundleIdentifier ?? items[index].sourceBundleIdentifier
            markChanged(items[index], at: date)
        } else {
            let item = ClipboardItem(payload: payload, createdAt: date, sourceBundleIdentifier: sourceBundleIdentifier)
            items.append(item)
            markChanged(item, at: date)
        }
        applyOrderingAndRetention(now: date)
    }

    func use(_ item: ClipboardItem, date: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index].lastUsedAt = date
        markChanged(items[index], at: date)
        applyOrderingAndRetention(now: date, persistence: .deferred)
    }

    func togglePinSelected() {
        guard let selectedItemID, let index = items.firstIndex(where: { $0.id == selectedItemID }) else {
            return
        }
        items[index].isPinned.toggle()
        markChanged(items[index])
        applyOrderingAndRetention(now: Date())
    }

    func togglePin(_ item: ClipboardItem) {
        selectedItemID = item.id
        togglePinSelected()
    }

    @discardableResult
    func deleteSelected() -> ClipboardItem? {
        guard let selectedItemID else {
            return nil
        }
        let deleted = items.first { $0.id == selectedItemID }
        if let deleted {
            markDeleted(deleted)
        }
        items.removeAll { $0.id == selectedItemID }
        applyOrderingAndRetention(now: Date())
        return deleted
    }

    @discardableResult
    func delete(_ item: ClipboardItem) -> ClipboardItem? {
        selectedItemID = item.id
        return deleteSelected()
    }

    @discardableResult
    func clearUnpinned() -> [ClipboardItem] {
        let removed = items.filter { !$0.isPinned }
        removed.forEach(markDeleted)
        items.removeAll { !$0.isPinned }
        applyOrderingAndRetention(now: Date())
        return removed
    }

    @discardableResult
    func clearAll() -> [ClipboardItem] {
        let removed = items
        removed.forEach(markDeleted)
        items.removeAll()
        applyOrderingAndRetention(now: Date())
        return removed
    }

    func restore(_ restoredItems: [ClipboardItem]) {
        let existingIDs = Set(items.map(\.id))
        let now = Date()
        let missingItems = restoredItems.filter { !existingIDs.contains($0.id) }.map { item in
            var restoredItem = item
            restoredItem.lastUsedAt = now
            return restoredItem
        }
        guard !missingItems.isEmpty else {
            return
        }
        items.append(contentsOf: missingItems)
        missingItems.forEach { markChanged($0, at: now) }
        applyOrderingAndRetention(now: now)
    }

    func selectNext() {
        moveSelection(offset: 1)
    }

    func selectPrevious() {
        moveSelection(offset: -1)
    }

    func selectAdjacentFilter(offset: Int) {
        let filters = ClipboardFilter.allCases
        guard let currentIndex = filters.firstIndex(of: selectedFilter) else {
            selectedFilter = .all
            return
        }
        selectedFilter = filters[(currentIndex + offset + filters.count) % filters.count]
    }

    func select(_ item: ClipboardItem) {
        selectedItemID = item.id
    }

    @discardableResult
    func updatePolicy(_ policy: ClipboardHistoryPolicy, now: Date = Date()) -> [ClipboardItem] {
        let previousItems = items
        self.policy = policy
        applyOrderingAndRetention(now: now)
        let remainingIDs = Set(items.map(\.id))
        return previousItems.filter { !remainingIDs.contains($0.id) }
    }

    func applyOrderingAndRetention(now: Date) {
        applyOrderingAndRetention(now: now, persistence: .immediate)
    }

    private func applyOrderingAndRetention(now: Date, persistence: PersistenceMode) {
        let removed = enforceRetention(now: now)
        removed.forEach(markDeleted)
        items = ordered(items)
        rebuildVisibleItems()
        persist(persistence)
    }

    func filteredItems(query: String, filter: ClipboardFilter) -> [ClipboardItem] {
        let parsedQuery = ClipboardSearchQuery(query)
        return items.filter { item in
            item.matches(filter: filter, parsedQuery: parsedQuery) &&
            parsedQuery.matches(item)
        }
    }

    func exportPinnedData() throws -> Data {
        let archive = PinnedClipboardArchive(items: items.filter(\.isPinned))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive)
    }

    @discardableResult
    func importPinnedData(_ data: Data, date: Date = Date()) throws -> [ClipboardItem] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(PinnedClipboardArchive.self, from: data)
        let existingHashes = Set(items.map(\.payloadHash))
        let imported = archive.items.compactMap { item -> ClipboardItem? in
            guard !existingHashes.contains(item.payloadHash) else {
                return nil
            }
            var importedItem = item
            importedItem.id = UUID()
            importedItem.createdAt = date
            importedItem.lastUsedAt = date
            importedItem.isPinned = true
            return importedItem
        }
        guard !imported.isEmpty else {
            return []
        }
        items.append(contentsOf: imported)
        imported.forEach { markChanged($0, at: date) }
        applyOrderingAndRetention(now: date)
        return imported
    }

    func prepareForRemoteChangeNotifications() async {
        guard let syncService else {
            return
        }
        try? await syncService.prepareForRemoteChangeNotifications()
    }

    func synchronize() async {
        guard let syncService else {
            syncState = .unavailable("iCloud sync is not configured.")
            return
        }
        if syncState.isSyncing {
            syncRequestedWhileSyncing = true
            return
        }

        syncTask?.cancel()
        syncTask = nil
        syncState = .syncing
        repeat {
            syncRequestedWhileSyncing = false
            do {
                let mergedRecords = try await syncService.synchronize(localRecords: makeSyncRecords())
                applySyncedRecords(mergedRecords)
            } catch let error as ClipSyncError {
                syncState = .unavailable(error.localizedDescription)
                return
            } catch {
                syncState = .failed("Couldn’t sync with iCloud. Try again.")
                return
            }
        } while syncRequestedWhileSyncing

        syncState = .synced(Date())
    }

    func cancelPendingSync() {
        syncTask?.cancel()
        syncTask = nil
        syncRequestedWhileSyncing = false
    }

    var isCloudSyncAvailable: Bool {
        syncService != nil
    }

    func synchronizeAfterRemoteChange() async {
        guard isCloudSyncAvailable else {
            return
        }
        await synchronize()
    }

    private func rebuildVisibleItems() {
        let nextVisibleItems = filteredItems(query: searchQuery, filter: selectedFilter)
        if nextVisibleItems.map(\.id) != visibleItems.map(\.id) {
            visibleItemsRevision += 1
        }
        visibleItems = nextVisibleItems
        pinnedItemCount = items.reduce(0) { count, item in
            count + (item.isPinned ? 1 : 0)
        }
        if let selectedItemID, visibleItems.contains(where: { $0.id == selectedItemID }) {
            return
        }
        selectedItemID = visibleItems.first?.id
    }

    private func moveSelection(offset: Int) {
        guard !visibleItems.isEmpty else {
            selectedItemID = nil
            return
        }
        guard let currentID = selectedItemID, let current = visibleItems.firstIndex(where: { $0.id == currentID }) else {
            selectedItemID = visibleItems.first?.id
            return
        }
        let next = max(0, min(visibleItems.count - 1, current + offset))
        selectedItemID = visibleItems[next].id
    }

    @discardableResult
    private func enforceRetention(now: Date) -> [ClipboardItem] {
        let previousItems = items
        items.removeAll { item in
            guard !item.isPinned, let retention = policy.retention.timeInterval else {
                return false
            }
            return now.timeIntervalSince(activityDate(item)) > retention
        }

        let unpinned = items.filter { !$0.isPinned }
        if unpinned.count > policy.limit.rawValue {
            let allowed = Set(unpinned.sorted { activityDate($0) > activityDate($1) }.prefix(policy.limit.rawValue).map(\.id))
            items.removeAll { !$0.isPinned && !allowed.contains($0.id) }
        }

        let remainingIDs = Set(items.map(\.id))
        return previousItems.filter { !remainingIDs.contains($0.id) }
    }

    private func ordered(_ source: [ClipboardItem]) -> [ClipboardItem] {
        source.sorted { $0.createdAt > $1.createdAt }
    }

    private func activityDate(_ item: ClipboardItem) -> Date {
        max(item.createdAt, item.lastUsedAt)
    }

    private func persist(_ mode: PersistenceMode) {
        let snapshot = StoredClipboardSnapshot(items: items)
        persistSyncMetadata()
        scheduleSyncIfAvailable()
        persistTask?.cancel()
        persistTask = Task { [historyStore] in
            if mode == .deferred {
                do {
                    try await Task.sleep(for: .milliseconds(350))
                } catch {
                    return
                }
            }
            try? await historyStore.save(snapshot)
        }
    }

    func flushPendingSave() async {
        persistTask?.cancel()
        persistTask = nil
        let snapshot = StoredClipboardSnapshot(items: items)
        try? await historyStore.save(snapshot)
    }

    private func persistSyncMetadata() {
        guard syncService != nil else {
            return
        }
        guard let data = try? JSONEncoder().encode(syncMetadata) else {
            return
        }
        syncDefaults.set(data, forKey: syncMetadataKey)
    }

    private func scheduleSyncIfAvailable() {
        guard syncService != nil, !isApplyingSync else {
            return
        }
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(650))
            } catch {
                return
            }
            guard let self, !Task.isCancelled else {
                return
            }
            self.syncTask = nil
            await self.synchronize()
        }
    }

    private func markChanged(_ item: ClipboardItem, at date: Date = Date()) {
        guard syncService != nil else {
            return
        }
        syncMetadata.modifiedAtByRecordName[item.id.uuidString] = date
        if let record = makeSyncedClip(from: item, modifiedAt: date) {
            syncMetadata.tombstones.removeAll { $0.fingerprint == record.fingerprint }
        }
    }

    private func markDeleted(_ item: ClipboardItem) {
        guard syncService != nil else {
            return
        }
        let date = Date()
        guard let record = makeSyncedClip(from: item, modifiedAt: date) else {
            return
        }
        syncMetadata.modifiedAtByRecordName.removeValue(forKey: item.id.uuidString)
        syncMetadata.tombstones.removeAll { $0.fingerprint == record.fingerprint }
        syncMetadata.tombstones.append(record.tombstone(at: date, originDeviceID: syncMetadata.originDeviceID))
    }

    private func makeSyncRecords() -> [SyncedClip] {
        let activeRecords = items.compactMap { item -> SyncedClip? in
            let modifiedAt = syncMetadata.modifiedAtByRecordName[item.id.uuidString] ?? activityDate(item)
            return makeSyncedClip(from: item, modifiedAt: modifiedAt)
        }
        return activeRecords.filter(\.isEligibleForCloud) + syncMetadata.tombstones
    }

    private func makeSyncedClip(from item: ClipboardItem, modifiedAt: Date) -> SyncedClip? {
        let kind: SyncedClipKind
        let content: String?
        let imageData: Data?
        switch item.payload {
        case .text(let text):
            kind = .text
            content = text
            imageData = nil
        case .url(let url):
            kind = .link
            content = url.absoluteString
            imageData = nil
        case .image(let data, _):
            kind = .image
            content = nil
            imageData = data
        case .files:
            return nil
        }

        return SyncedClip(
            recordName: item.id.uuidString,
            fingerprint: SyncedClip.fingerprint(kind: kind, content: content, imageData: imageData),
            kind: kind,
            content: content,
            imageData: imageData,
            createdAt: item.createdAt,
            lastUsedAt: item.lastUsedAt,
            isPinned: item.isPinned,
            modifiedAt: modifiedAt,
            originDeviceID: syncMetadata.originDeviceID,
            isDeleted: false
        )
    }

    private func applySyncedRecords(_ records: [SyncedClip]) {
        isApplyingSync = true
        let repairedRecords = repairingLegacyLinkRecords(records)
        var needsFollowUpSync = repairedRecords.didRepair
        defer {
            isApplyingSync = false
            if needsFollowUpSync {
                scheduleSyncIfAvailable()
            }
        }

        var nextItems = items
        var nextVersions: [String: Date] = [:]
        var nextTombstones: [SyncedClip] = []

        for record in repairedRecords.records {
            if record.isDeleted {
                nextItems.removeAll { item in
                    item.id.uuidString == record.recordName || item.syncFingerprint == record.fingerprint
                }
                nextTombstones.append(record)
                continue
            }
            guard let item = ClipboardItem(syncedRecord: record) else {
                continue
            }
            nextItems.removeAll { existing in
                existing.id == item.id || existing.syncFingerprint == record.fingerprint
            }
            nextItems.append(item)
            nextVersions[item.id.uuidString] = record.modifiedAt
        }

        syncMetadata.modifiedAtByRecordName = nextVersions
        syncMetadata.tombstones = nextTombstones
        items = ordered(nextItems)
        let removed = enforceRetention(now: Date())
        removed.forEach(markDeleted)
        needsFollowUpSync = needsFollowUpSync || removed.contains {
            makeSyncedClip(from: $0, modifiedAt: Date()) != nil
        }
        rebuildVisibleItems()
        persistSyncMetadata()
        let snapshot = StoredClipboardSnapshot(items: items)
        persistTask?.cancel()
        persistTask = Task { [historyStore] in
            try? await historyStore.save(snapshot)
        }
    }

    private func repairingLegacyLinkRecords(
        _ records: [SyncedClip]
    ) -> (records: [SyncedClip], didRepair: Bool) {
        var repairedRecords: [SyncedClip] = []
        var didRepair = false
        let repairDate = Date()

        for record in records {
            guard !record.isDeleted,
                  record.kind == .link,
                  let content = record.content,
                  ClipboardContentCleaner.webURL(from: content) == nil
            else {
                repairedRecords.append(record)
                continue
            }

            let decodedContent = content.removingPercentEncoding ?? content
            let normalizedContent = ClipboardContentCleaner.normalizedText(decodedContent)
            guard !normalizedContent.isEmpty else {
                repairedRecords.append(record)
                continue
            }

            repairedRecords.append(
                record.tombstone(
                    at: repairDate,
                    originDeviceID: syncMetadata.originDeviceID
                )
            )
            repairedRecords.append(
                SyncedClip(
                    recordName: UUID().uuidString,
                    fingerprint: SyncedClip.fingerprint(kind: .text, content: normalizedContent),
                    kind: .text,
                    content: normalizedContent,
                    imageData: nil,
                    createdAt: record.createdAt,
                    lastUsedAt: record.lastUsedAt,
                    isPinned: record.isPinned,
                    modifiedAt: repairDate,
                    originDeviceID: syncMetadata.originDeviceID,
                    isDeleted: false
                )
            )
            didRepair = true
        }

        return (repairedRecords, didRepair)
    }
}

private extension ClipboardItem {
    var syncFingerprint: String? {
        switch payload {
        case .text(let text):
            SyncedClip.fingerprint(kind: .text, content: text)
        case .url(let url):
            SyncedClip.fingerprint(kind: .link, content: url.absoluteString)
        case .image(let data, _):
            SyncedClip.fingerprint(kind: .image, imageData: data)
        case .files:
            nil
        }
    }

    init?(syncedRecord record: SyncedClip) {
        guard let id = UUID(uuidString: record.recordName), let kind = record.kind else {
            return nil
        }
        let payload: ClipboardPayload
        switch kind {
        case .text:
            guard let content = record.content else { return nil }
            payload = .text(content)
        case .link:
            guard let content = record.content,
                  let url = ClipboardContentCleaner.webURL(from: content)
            else { return nil }
            payload = .url(url)
        case .image:
            guard let imageData = record.imageData else { return nil }
            payload = .image(data: imageData, uti: nil)
        }
        self.init(
            id: id,
            payload: payload,
            createdAt: record.createdAt,
            lastUsedAt: record.lastUsedAt,
            isPinned: record.isPinned,
            sourceBundleIdentifier: nil
        )
    }
}

private enum PersistenceMode: Sendable {
    case immediate
    case deferred
}

private struct PinnedClipboardArchive: Codable {
    var version = 1
    var exportedAt = Date()
    var items: [ClipboardItem]
}

private struct ClipboardSearchQuery {
    enum DateScope {
        case today
        case yesterday
    }

    var terms: [String] = []
    var kind: ClipboardItemKind?
    var pinned: Bool?
    var source: String?
    var dateScope: DateScope?

    init(_ rawValue: String) {
        for token in rawValue.split(whereSeparator: \.isWhitespace).map(String.init) {
            let lowercased = token.lowercased()
            if let value = lowercased.value(afterPrefix: "kind:") ?? lowercased.value(afterPrefix: "type:") {
                kind = ClipboardItemKind(searchToken: value)
            } else if let value = lowercased.value(afterPrefix: "from:") ?? lowercased.value(afterPrefix: "app:") {
                source = value
            } else if let value = lowercased.value(afterPrefix: "is:") {
                pinned = value == "pinned" ? true : value == "unpinned" ? false : pinned
            } else if lowercased == "pinned" {
                pinned = true
            } else if lowercased == "today" {
                dateScope = .today
            } else if lowercased == "yesterday" {
                dateScope = .yesterday
            } else {
                terms.append(token)
            }
        }
    }

    func matches(_ item: ClipboardItem) -> Bool {
        if let kind, item.kind != kind {
            return false
        }
        if let pinned, item.isPinned != pinned {
            return false
        }
        if let source,
           item.sourceBundleIdentifier?.localizedCaseInsensitiveContains(source) != true {
            return false
        }
        if let dateScope, !matches(item.lastUsedAt, scope: dateScope) {
            return false
        }
        return terms.allSatisfy { item.payload.searchText.localizedStandardContains($0) }
    }

    private func matches(_ date: Date, scope: DateScope) -> Bool {
        let calendar = Calendar.current
        switch scope {
        case .today:
            return calendar.isDateInToday(date)
        case .yesterday:
            return calendar.isDateInYesterday(date)
        }
    }
}

private extension ClipboardItem {
    func matches(filter: ClipboardFilter, parsedQuery: ClipboardSearchQuery) -> Bool {
        switch filter {
        case .all:
            return parsedQuery.pinned == true || !isPinned
        case .pinned:
            return isPinned
        case .text:
            return kind == .text && (parsedQuery.pinned == true || !isPinned)
        case .url:
            return kind == .url && (parsedQuery.pinned == true || !isPinned)
        case .image:
            return kind == .image && (parsedQuery.pinned == true || !isPinned)
        case .files:
            return kind == .files && (parsedQuery.pinned == true || !isPinned)
        }
    }
}

private extension ClipboardItemKind {
    init?(searchToken: String) {
        switch searchToken {
        case "text", "txt":
            self = .text
        case "url", "link", "links":
            self = .url
        case "image", "img", "photo":
            self = .image
        case "file", "files", "doc":
            self = .files
        default:
            return nil
        }
    }
}

private extension String {
    func value(afterPrefix prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }
        return String(dropFirst(prefix.count))
    }
}
