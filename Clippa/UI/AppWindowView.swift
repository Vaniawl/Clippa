import AppKit
import SwiftUI

enum AppWindowSection: String, CaseIterable, Identifiable {
    case history
    case settings
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: String(localized: "History")
        case .settings: String(localized: "Settings")
        case .privacy: String(localized: "Privacy")
        }
    }

    var symbolName: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        case .privacy: "lock.shield"
        }
    }
}

struct AppWindowView: View {
    @Bindable var settings: AppSettings
    @Bindable var store: ClipboardStore
    let hotKeyStatus: String
    let onShowShortcutChange: (HotKeyShortcut) -> Void
    let onPinShortcutChange: (HotKeyShortcut) -> Void
    let onPaste: @MainActor (ClipboardItem) -> Void
    let onCopy: @MainActor (ClipboardItem) -> Void
    let onOpen: @MainActor (ClipboardItem) -> Void
    let onReveal: @MainActor (ClipboardItem) -> Void
    @State private var selectedSection: AppWindowSection?
    @State private var confirmClearUnpinned = false
    @State private var toast: ActionToast?

    init(
        settings: AppSettings,
        store: ClipboardStore,
        hotKeyStatus: String,
        initialSelection: AppWindowSection,
        onShowShortcutChange: @escaping (HotKeyShortcut) -> Void,
        onPinShortcutChange: @escaping (HotKeyShortcut) -> Void,
        onPaste: @escaping @MainActor (ClipboardItem) -> Void,
        onCopy: @escaping @MainActor (ClipboardItem) -> Void,
        onOpen: @escaping @MainActor (ClipboardItem) -> Void,
        onReveal: @escaping @MainActor (ClipboardItem) -> Void
    ) {
        self.settings = settings
        self.store = store
        self.hotKeyStatus = hotKeyStatus
        self.onShowShortcutChange = onShowShortcutChange
        self.onPinShortcutChange = onPinShortcutChange
        self.onPaste = onPaste
        self.onCopy = onCopy
        self.onOpen = onOpen
        self.onReveal = onReveal
        _selectedSection = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationSplitView {
            List(AppWindowSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                statusToast(toast)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.snappy(duration: 0.18), value: toast?.id)
        .toolbar {
            ToolbarItem {
                Button {
                    confirmClearUnpinned = true
                } label: {
                    Label("Clear unpinned history", systemImage: "trash")
                }
                .help(String(localized: "Clear unpinned history"))
            }
        }
        .confirmationDialog("Clear unpinned clipboard history?", isPresented: $confirmClearUnpinned) {
            Button("Clear unpinned history", role: .destructive) {
                let removed = store.clearUnpinned()
                showUndoToast(
                    message: String(localized: "Unpinned history cleared."),
                    restoredMessage: String(localized: "History restored."),
                    restoredItems: removed
                )
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedSection ?? .history {
        case .history:
            HistoryDashboardView(
                store: store,
                isAutoPasteReady: AccessibilityService.isTrusted,
                onPaste: onPaste,
                onCopy: { item in
                    onCopy(item)
                    showActionMessage(String(localized: "Copied to clipboard."))
                },
                onOpen: onOpen,
                onReveal: onReveal,
                onActionMessage: showActionMessage,
                onUndoableItemsRemoved: showUndoToast
            )
        case .settings:
            SettingsView(
                settings: settings,
                store: store,
                hotKeyStatus: hotKeyStatus,
                usesFixedFrame: false,
                onUndoableItemsRemoved: showUndoToast,
                onShowShortcutChange: onShowShortcutChange,
                onPinShortcutChange: onPinShortcutChange
            )
        case .privacy:
            PrivacyDashboardView()
        }
    }

    private func statusToast(_ toast: ActionToast) -> some View {
        HStack(spacing: 10) {
            Label(toast.message, systemImage: "checkmark.circle.fill")
            if let actionTitle = toast.actionTitle, let action = toast.action {
                Divider()
                    .frame(height: 14)
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .fontWeight(.medium)
            }
        }
        .font(.caption)
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
        .shadow(radius: 8, y: 4)
    }

    private func showActionMessage(_ message: String) {
        let nextToast = ActionToast(message: message)
        toast = nextToast
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if toast?.id == nextToast.id {
                toast = nil
            }
        }
    }

    private func showUndoToast(message: String, restoredMessage: String, restoredItems: [ClipboardItem]) {
        guard !restoredItems.isEmpty else {
            showActionMessage(message)
            return
        }
        let nextToast = ActionToast(
            message: message,
            actionTitle: String(localized: "Undo"),
            action: {
                store.restore(restoredItems)
                showActionMessage(restoredMessage)
            }
        )
        toast = nextToast
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            if toast?.id == nextToast.id {
                toast = nil
            }
        }
    }
}

private struct ActionToast: Identifiable {
    let id = UUID()
    let message: String
    var actionTitle: String?
    var action: (@MainActor () -> Void)?
}

private struct HistoryDashboardView: View {
    @Bindable var store: ClipboardStore
    var isAutoPasteReady: Bool
    let onPaste: @MainActor (ClipboardItem) -> Void
    let onCopy: @MainActor (ClipboardItem) -> Void
    let onOpen: @MainActor (ClipboardItem) -> Void
    let onReveal: @MainActor (ClipboardItem) -> Void
    let onActionMessage: @MainActor (String) -> Void
    let onUndoableItemsRemoved: @MainActor (_ message: String, _ restoredMessage: String, _ items: [ClipboardItem]) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var selectedItem: ClipboardItem? {
        guard let id = store.selectedItemID else { return nil }
        return store.visibleItems.first { $0.id == id } ?? store.items.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                listPane
                    .frame(minWidth: 420, idealWidth: 560)
                detailPane
                    .frame(minWidth: 260, idealWidth: 320)
            }
        }
        .navigationTitle("History")
        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: store.selectedFilter)
        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: store.searchQuery)
        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: store.selectedItemID)
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search clipboard", text: $store.searchQuery)
                        .textFieldStyle(.plain)
                    if !store.searchQuery.isEmpty {
                        Button {
                            animate { store.searchQuery = "" }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                        .help(String(localized: "Clear search"))
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(.tertiary.opacity(0.10), in: .rect(cornerRadius: 8))

                statusBadge(
                    title: isAutoPasteReady ? String(localized: "Auto-paste ready") : String(localized: "Copy only"),
                    symbol: isAutoPasteReady ? "checkmark.circle.fill" : "doc.on.doc",
                    color: isAutoPasteReady ? .green : .secondary
                )
            }

            filterRow
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var filterRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                filterButtons(showTitles: true)
                Spacer()
                stats
            }

            HStack(spacing: 6) {
                filterButtons(showTitles: false)
                Spacer()
                stats
            }
        }
    }

    private func filterButtons(showTitles: Bool) -> some View {
        ForEach(ClipboardFilter.allCases) { filter in
            Button {
                animate { store.selectedFilter = filter }
            } label: {
                if showTitles {
                    Label(filter.displayName, systemImage: filter.symbolName)
                        .labelStyle(.titleAndIcon)
                        .font(.callout)
                        .lineLimit(1)
                        .frame(minWidth: 68)
                        .padding(.horizontal, 8)
                        .frame(height: 30)
                } else {
                    Image(systemName: filter.symbolName)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 34, height: 30)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(store.selectedFilter == filter ? Color.accentColor : Color.secondary)
            .background(filterBackground(filter))
            .clipShape(.rect(cornerRadius: 7))
            .help(filter.displayName)
        }
    }

    private var stats: some View {
        HStack(spacing: 12) {
            stat(title: String(localized: "Items"), value: "\(store.items.count)")
            stat(title: String(localized: "Pinned"), value: "\(store.pinnedItemCount)")
        }
    }

    private var listPane: some View {
        Group {
            if store.visibleItems.isEmpty {
                ContentUnavailableView(
                    "No clipboard items",
                    systemImage: "tray",
                    description: Text("Copied text, links, images, and files will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.visibleItems, selection: $store.selectedItemID) { item in
                    DashboardClipboardRow(
                        item: item,
                        onDoubleClick: {
                            store.select(item)
                            onPaste(item)
                        }
                    )
                        .tag(item.id)
                        .contextMenu {
                            itemMenu(for: item)
                        }
                }
                .listStyle(.inset)
            }
        }
    }

    private var detailPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selectedItem {
                SelectedItemDetail(
                    item: selectedItem,
                    onPaste: { onPaste(selectedItem) },
                    onCopy: { onCopy(selectedItem) },
                    onOpen: { onOpen(selectedItem) },
                    onReveal: { onReveal(selectedItem) },
                    onTogglePin: {
                        store.togglePin(selectedItem)
                        onActionMessage(selectedItem.isPinned ? String(localized: "Unpinned.") : String(localized: "Pinned."))
                    },
                    onDelete: {
                        let deleted = store.delete(selectedItem).map { [$0] } ?? []
                        onUndoableItemsRemoved(
                            String(localized: "Deleted."),
                            String(localized: "Item restored."),
                            deleted
                        )
                    }
                )
            } else {
                ContentUnavailableView(
                    "No item selected",
                    systemImage: "sidebar.right",
                    description: Text("Select an item to preview it and choose an action.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.quaternary.opacity(0.08))
    }

    @ViewBuilder
    private func filterBackground(_ filter: ClipboardFilter) -> some View {
        if store.selectedFilter == filter {
            RoundedRectangle(cornerRadius: 7)
                .fill(contrast == .increased ? Color.accentColor.opacity(0.24) : Color.accentColor.opacity(0.12))
        }
    }

    private func statusBadge(title: String, symbol: String, color: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private func stat(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
    }

    @ViewBuilder
    private func itemMenu(for item: ClipboardItem) -> some View {
        Button("Paste") { onPaste(item) }
        Button("Copy") { onCopy(item) }
        Divider()
        if item.canOpen {
            Button(item.openTitle) { onOpen(item) }
        }
        if item.canReveal {
            Button("Reveal in Finder") { onReveal(item) }
        }
        Button(item.isPinned ? "Unpin" : "Pin") {
            let wasPinned = item.isPinned
            store.togglePin(item)
            onActionMessage(wasPinned ? String(localized: "Unpinned.") : String(localized: "Pinned."))
        }
        Divider()
        Button("Delete", role: .destructive) {
            let deleted = store.delete(item).map { [$0] } ?? []
            onUndoableItemsRemoved(
                String(localized: "Deleted."),
                String(localized: "Item restored."),
                deleted
            )
        }
    }

    private func animate(_ changes: @escaping () -> Void) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(.snappy(duration: 0.18), changes)
        }
    }
}

private struct DashboardClipboardRow: View {
    let item: ClipboardItem
    let onDoubleClick: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ClipboardThumbnailView(item: item, size: 36, cornerRadius: 8, showsPin: true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.rowTitle)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if item.kind != .image {
                        Text(item.kind.displayName)
                    }
                    if case .image = item.payload {
                        ClipboardImageInfoView(item: item)
                    }
                    if item.isPinned {
                        Label("Pinned", systemImage: "pin.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
    }
}

private struct SelectedItemDetail: View {
    let item: ClipboardItem
    let onPaste: @MainActor () -> Void
    let onCopy: @MainActor () -> Void
    let onOpen: @MainActor () -> Void
    let onReveal: @MainActor () -> Void
    let onTogglePin: @MainActor () -> Void
    let onDelete: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(item.kind.displayName, systemImage: item.kind.symbolName)
                        .font(.headline)
                    if item.kind == .image {
                        Text("Clipboard image")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(Color.accentColor)
                        .help(String(localized: "Pinned"))
                }
            }

            preview
                .frame(maxWidth: .infinity, minHeight: 140, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if let source = sourceName {
                    LabeledContent("Source", value: source)
                }
                if item.kind == .image {
                    ClipboardImageInfoView(item: item)
                }
            }
            .font(.caption)

            Divider()

            HStack(spacing: 8) {
                Button {
                    onPaste()
                } label: {
                    Label("Paste", systemImage: "arrow.down.doc")
                }
                .keyboardShortcut(.return, modifiers: [])

                Button {
                    onCopy()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                if item.canOpen {
                    Button {
                        onOpen()
                    } label: {
                        Label("Open", systemImage: "arrow.up.forward.app")
                    }
                }

                if item.canReveal {
                    Button {
                        onReveal()
                    } label: {
                        Label("Reveal in Finder", systemImage: "finder")
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    onTogglePin()
                } label: {
                    Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                }
                .keyboardShortcut("p", modifiers: .command)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .keyboardShortcut(.delete, modifiers: [])
            }
        }
        .padding(18)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.payload {
        case .text(let text):
            ScrollView {
                Text(text.isEmpty ? String(localized: "Empty text") : text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.vertical, 4)
            }
        case .url(let url):
            VStack(alignment: .leading, spacing: 8) {
                Text(url.absoluteString)
                    .textSelection(.enabled)
                    .font(.body)
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open URL", systemImage: "safari")
                }
            }
        case .image(let data, _):
            if let image = ClipboardImageCache.image(for: item.payloadHash, data: data) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        Color.secondary.opacity(0.08)
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(10)
                    }
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.08))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Image details", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ClipboardImageInfoView(item: item)
                    }
                }
            } else {
                Text(item.preview)
                    .foregroundStyle(.secondary)
            }
        case .files(let refs):
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(refs, id: \.self) { ref in
                        Label(ref.displayName, systemImage: ref.exists ? "doc" : "exclamationmark.triangle")
                            .foregroundStyle(ref.exists ? Color.primary : Color.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var sourceName: String? {
        item.cachedSourceName
    }
}

private struct PrivacyDashboardView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Private clipboard history", systemImage: "lock.shield")
                        .font(.title2.weight(.semibold))
                    Text("Clippa does not upload clipboard contents, does not use analytics, and does not require an account.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    privacyCard(
                        title: String(localized: "On this Mac"),
                        message: String(localized: "Clipboard history is stored locally, not in Clippa cloud storage."),
                        symbol: "macbook"
                    )
                    privacyCard(
                        title: String(localized: "Encrypted"),
                        message: String(localized: "History is encrypted with a Keychain-backed AES-GCM key."),
                        symbol: "key.fill"
                    )
                    privacyCard(
                        title: String(localized: "No tracking"),
                        message: String(localized: "No analytics, telemetry, ads, or account login are built into Clippa."),
                        symbol: "eye.slash.fill"
                    )
                }

                SettingsPanel(title: String(localized: "Permissions")) {
                    statusRow(
                        title: String(localized: "Accessibility"),
                        value: AccessibilityService.isTrusted ? String(localized: "Granted") : String(localized: "Required for automatic paste"),
                        symbol: AccessibilityService.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        color: AccessibilityService.isTrusted ? .green : .orange
                    )
                    Text("Accessibility is only used to paste the selected clip into the frontmost app.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Request Access") {
                        AccessibilityService.requestPrompt()
                    }
                    Button("Open Privacy & Security") {
                        AccessibilityService.openSystemSettings()
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Privacy")
    }

    private func privacyCard(title: String, message: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator.opacity(0.5))
        }
    }

    private func statusRow(title: String, value: String, symbol: String, color: Color) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.secondary)
        } label: {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(color)
            }
        }
    }
}

private extension ClipboardItem {
    var rowTitle: String {
        if kind == .image {
            return String(localized: "Clipboard image")
        }
        return preview.isEmpty ? String(localized: "Empty text") : preview
    }

    var canOpen: Bool {
        switch payload {
        case .url:
            true
        case .files(let refs):
            refs.contains(where: \.exists)
        case .text, .image:
            false
        }
    }

    var canReveal: Bool {
        if case .files(let refs) = payload {
            refs.contains(where: \.exists)
        } else {
            false
        }
    }

    var openTitle: String {
        switch payload {
        case .url:
            String(localized: "Open URL")
        case .files:
            String(localized: "Open File")
        case .text, .image:
            String(localized: "Open")
        }
    }
}
