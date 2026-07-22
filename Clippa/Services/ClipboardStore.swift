import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ClipboardStore {
    private(set) var items: [ClipboardItem] = []
    private(set) var visibleItems: [ClipboardItem] = []
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
        applyOrderingAndRetention(now: date)
    }

    func togglePinSelected() {
        guard let selectedItemID, let index = items.firstIndex(where: { $0.id == selectedItemID }) else {
            return
        }
        items[index].isPinned.toggle()
        applyOrderingAndRetention(now: Date())
    }

    func deleteSelected() {
        guard let selectedItemID else {
            return
        }
        items.removeAll { $0.id == selectedItemID }
        applyOrderingAndRetention(now: Date())
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        applyOrderingAndRetention(now: Date())
    }

    func clearAll() {
        items.removeAll()
        applyOrderingAndRetention(now: Date())
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
        enforceRetention(now: now)
        items = ordered(items)
        rebuildVisibleItems()
        persist()
    }

    func filteredItems(query: String, filter: ClipboardFilter) -> [ClipboardItem] {
        let filteredByKind: [ClipboardItem]
        switch filter {
        case .all:
            filteredByKind = items
        case .text:
            filteredByKind = items.filter { $0.kind == .text || $0.kind == .url }
        case .image:
            filteredByKind = items.filter { $0.kind == .image }
        }

        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else {
            return filteredByKind
        }
        return filteredByKind.filter { $0.payload.searchText.localizedStandardContains(cleanedQuery) }
    }

    private func rebuildVisibleItems() {
        visibleItems = filteredItems(query: searchQuery, filter: selectedFilter)
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
            !item.isPinned && now.timeIntervalSince(item.createdAt) > retention
        }

        let unpinned = items.filter { !$0.isPinned }
        if unpinned.count > maxUnpinnedCount {
            let allowed = Set(unpinned.sorted { $0.createdAt > $1.createdAt }.prefix(maxUnpinnedCount).map(\.id))
            items.removeAll { !$0.isPinned && !allowed.contains($0.id) }
        }
    }

    private func ordered(_ source: [ClipboardItem]) -> [ClipboardItem] {
        source.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private func persist() {
        let snapshot = StoredClipboardSnapshot(items: items)
        Task {
            try? await historyStore.save(snapshot)
        }
    }
}
