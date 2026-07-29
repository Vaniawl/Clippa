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
    private(set) var undoMessage: String?
    var searchQuery: String = "" {
        didSet { rebuildVisibleItems() }
    }
    var selectedFilter: ClipboardFilter = .all {
        didSet { rebuildVisibleItems() }
    }
    var storageMessage: String?

    private let historyStore: EncryptedHistoryStore
    private let persistenceEnabled: Bool
    private var policy: ClipboardHistoryPolicy
    private var persistTask: Task<Void, Never>?
    private var persistGeneration = 0

    init(
        historyStore: EncryptedHistoryStore = EncryptedHistoryStore(),
        policy: ClipboardHistoryPolicy = .default,
        persistenceEnabled: Bool = true
    ) {
        self.historyStore = historyStore
        self.policy = policy
        self.persistenceEnabled = persistenceEnabled
    }

    func load() async {
        do {
            let snapshot = try await historyStore.load()
            items = ordered(snapshot.items)
            enforceRetention(now: Date())
            rebuildVisibleItems()
            storageMessage = await historyStore.recoveryMessage()
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
        } else {
            items.append(ClipboardItem(payload: payload, createdAt: date, sourceBundleIdentifier: sourceBundleIdentifier))
        }
        applyOrderingAndRetention(now: date)
    }

    func use(_ item: ClipboardItem, date: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index].lastUsedAt = date
        applyOrderingAndRetention(now: date, persistence: .deferred)
    }

    func togglePinSelected() {
        guard let selectedItemID, let index = items.firstIndex(where: { $0.id == selectedItemID }) else {
            return
        }
        items[index].isPinned.toggle()
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
        items.removeAll { !$0.isPinned }
        applyOrderingAndRetention(now: Date())
        return removed
    }

    @discardableResult
    func clearAll() -> [ClipboardItem] {
        let removed = items
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

    func showUndoMessage(_ message: String) {
        undoMessage = message
    }

    func dismissUndoMessage() {
        undoMessage = nil
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
        enforceRetention(now: now)
        items = ordered(items)
        rebuildVisibleItems()
        persist(persistence)
    }

    func filteredItems(query: String, filter: ClipboardFilter) -> [ClipboardItem] {
        let parsedQuery = ClipboardSearchQuery(query)
        let matches = items.filter { item in
            item.matches(filter: filter) &&
            parsedQuery.matches(item)
        }
        guard filter == .all else {
            return matches
        }
        return matches.filter(\.isPinned) + matches.filter { !$0.isPinned }
    }

    func exportPinnedData() throws -> Data {
        let archive = PinnedClipboardArchive(items: items.filter(\.isPinned))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive)
    }

    func exportResolvedPinnedData() async throws -> Data {
        var resolvedItems: [ClipboardItem] = []
        for item in items where item.isPinned {
            resolvedItems.append(try await resolvedItem(item))
        }
        let archive = PinnedClipboardArchive(items: resolvedItems)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive)
    }

    func resolvedItem(_ item: ClipboardItem) async throws -> ClipboardItem {
        let payload = try await historyStore.resolvePayload(item.payload)
        guard payload != item.payload else {
            return item
        }
        var resolved = item
        resolved.payload = payload
        return resolved
    }

    func imageData(for payload: ClipboardPayload) async throws -> Data {
        try await historyStore.loadImageData(for: payload)
    }

    func reportStorageFailure(_ operation: String) {
        storageMessage = String(localized: "\(operation) failed because encrypted clipboard data could not be read or written.")
    }

    func dismissStorageMessage() {
        storageMessage = nil
    }

    @discardableResult
    func importPinnedData(_ data: Data, date: Date = Date()) throws -> [ClipboardItem] {
        guard data.count <= ClipboardPayloadLimits.maximumImportByteCount else {
            throw PinnedClipboardArchiveError.archiveTooLarge
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(PinnedClipboardArchive.self, from: data)
        guard archive.version == 1,
              archive.items.count <= ClipboardPayloadLimits.maximumImportItemCount
        else {
            throw PinnedClipboardArchiveError.unsupportedArchive
        }
        var existingHashes = Set(items.map(\.payloadHash))
        let imported = archive.items.compactMap { item -> ClipboardItem? in
            let payloadHash = item.payload.stableHash
            guard Self.isSafeImportedPayload(item.payload),
                  !existingHashes.contains(payloadHash)
            else {
                return nil
            }
            existingHashes.insert(payloadHash)
            return ClipboardItem(
                payload: item.payload,
                createdAt: date,
                lastUsedAt: date,
                isPinned: true,
                sourceBundleIdentifier: item.sourceBundleIdentifier
            )
        }
        guard !imported.isEmpty else {
            return []
        }
        items.append(contentsOf: imported)
        applyOrderingAndRetention(now: date)
        return imported
    }

    private static func isSafeImportedPayload(_ payload: ClipboardPayload) -> Bool {
        switch payload {
        case .text(let value):
            return value.utf8.count <= ClipboardPayloadLimits.maximumTextByteCount
        case .url(let url):
            return url.absoluteString.utf8.count <= ClipboardPayloadLimits.maximumTextByteCount
        case .image(let data, _):
            return data.count <= ClipboardPayloadLimits.maximumImageByteCount
        case .files(let references):
            return references.count <= ClipboardPayloadLimits.maximumFileCount
        case .storedImage:
            return false
        }
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

    private func enforceRetention(now: Date) {
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

        let pinnedByteCount = items.lazy.filter(\.isPinned).reduce(0) {
            $0 + estimatedByteCount(of: $1)
        }
        var remainingByteCount = max(0, policy.diskBudget.byteCount - pinnedByteCount)
        let allowedUnpinnedIDs = Set(
            items
                .filter { !$0.isPinned }
                .sorted { activityDate($0) > activityDate($1) }
                .compactMap { item -> ClipboardItem.ID? in
                    let byteCount = estimatedByteCount(of: item)
                    guard byteCount <= remainingByteCount else {
                        return nil
                    }
                    remainingByteCount -= byteCount
                    return item.id
                }
        )
        items.removeAll { !$0.isPinned && !allowedUnpinnedIDs.contains($0.id) }
    }

    private func ordered(_ source: [ClipboardItem]) -> [ClipboardItem] {
        source.sorted { $0.createdAt > $1.createdAt }
    }

    private func activityDate(_ item: ClipboardItem) -> Date {
        max(item.createdAt, item.lastUsedAt)
    }

    private func estimatedByteCount(of item: ClipboardItem) -> Int {
        let metadataOverhead = 512
        switch item.payload {
        case .text(let value):
            return value.utf8.count + metadataOverhead
        case .url(let url):
            return url.absoluteString.utf8.count + metadataOverhead
        case .image(let data, _):
            return data.count + metadataOverhead
        case .storedImage(_, _, let metadata, _):
            return metadata.byteCount + metadataOverhead
        case .files(let references):
            return references.reduce(metadataOverhead) {
                $0 + $1.path.utf8.count + ($1.bookmarkData?.count ?? 0)
            }
        }
    }

    private func persist(_ mode: PersistenceMode) {
        guard persistenceEnabled else {
            return
        }
        let snapshot = StoredClipboardSnapshot(items: items)
        persistGeneration += 1
        let generation = persistGeneration
        persistTask?.cancel()
        persistTask = Task { [weak self, historyStore] in
            if mode == .deferred {
                do {
                    try await Task.sleep(for: .milliseconds(350))
                } catch {
                    return
                }
            }
            do {
                try await historyStore.save(snapshot, generation: generation)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.persistGeneration == generation else {
                    return
                }
                self.reportStorageFailure(String(localized: "Saving clipboard history"))
            }
        }
    }

    func flushPendingSave() async throws {
        guard persistenceEnabled else {
            return
        }
        persistTask?.cancel()
        persistTask = nil
        persistGeneration += 1
        let snapshot = StoredClipboardSnapshot(items: items)
        do {
            try await historyStore.save(snapshot, generation: persistGeneration)
        } catch {
            reportStorageFailure(String(localized: "Saving clipboard history"))
            throw error
        }
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

private enum PinnedClipboardArchiveError: Error {
    case archiveTooLarge
    case unsupportedArchive
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
    func matches(filter: ClipboardFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .pinned:
            return isPinned
        case .text:
            return kind == .text
        case .url:
            return kind == .url
        case .image:
            return kind == .image
        case .files:
            return kind == .files
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
