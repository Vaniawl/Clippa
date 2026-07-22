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

    private let historyStore: EncryptedHistoryStore
    private let maxUnpinnedCount = 100
    private let retention: TimeInterval = 7 * 24 * 60 * 60
    private var persistTask: Task<Void, Never>?

    init(historyStore: EncryptedHistoryStore = EncryptedHistoryStore()) {
        self.historyStore = historyStore
    }

    func load() async {
        do {
            let snapshot = try await historyStore.load()
            items = ordered(snapshot.items)
            enforceRetention(now: Date())
            rebuildVisibleItems()
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

    func select(_ item: ClipboardItem) {
        selectedItemID = item.id
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
        let filteredByKind: [ClipboardItem]
        switch filter {
        case .all:
            filteredByKind = items
        case .pinned:
            filteredByKind = items.filter(\.isPinned)
        case .text:
            filteredByKind = items.filter { $0.kind == .text }
        case .url:
            filteredByKind = items.filter { $0.kind == .url }
        case .image:
            filteredByKind = items.filter { $0.kind == .image }
        case .files:
            filteredByKind = items.filter { $0.kind == .files }
        }

        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else {
            return filteredByKind
        }
        return filteredByKind.filter { $0.payload.searchText.localizedStandardContains(cleanedQuery) }
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
            !item.isPinned && now.timeIntervalSince(activityDate(item)) > retention
        }

        let unpinned = items.filter { !$0.isPinned }
        if unpinned.count > maxUnpinnedCount {
            let allowed = Set(unpinned.sorted { activityDate($0) > activityDate($1) }.prefix(maxUnpinnedCount).map(\.id))
            items.removeAll { !$0.isPinned && !allowed.contains($0.id) }
        }
    }

    private func ordered(_ source: [ClipboardItem]) -> [ClipboardItem] {
        source.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return activityDate($0) > activityDate($1)
        }
    }

    private func activityDate(_ item: ClipboardItem) -> Date {
        max(item.createdAt, item.lastUsedAt)
    }

    private func persist(_ mode: PersistenceMode) {
        let snapshot = StoredClipboardSnapshot(items: items)
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
}

private enum PersistenceMode: Sendable {
    case immediate
    case deferred
}
