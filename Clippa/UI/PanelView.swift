import AppKit
import SwiftUI

struct PanelPasteDestination: Equatable {
    let applicationName: String
    let bundleIdentifier: String?
}

struct PanelView: View {
    @Bindable var store: ClipboardStore
    var pasteDestination: PanelPasteDestination?
    var onPasteSelected: @MainActor () -> Void
    var onPasteAsPlainText: @MainActor (ClipboardItem) -> Void
    var onCopy: @MainActor (ClipboardItem) -> Void
    var onPreview: @MainActor (ClipboardItem) -> Void
    var onOpen: @MainActor (ClipboardItem) -> Void
    var onExtractText: @MainActor (ClipboardItem) -> Void
    var onTogglePin: @MainActor (ClipboardItem) -> Void
    var onDelete: @MainActor (ClipboardItem) -> Void
    var onUndo: @MainActor () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var isSearchFocused: Bool
    @State private var isShowingSearchHelp = false

    private let metrics = DesignSystem.panelMetrics

    var body: some View {
        VStack(spacing: metrics.contentSpacing) {
            headerRow
            searchField
            filterBar

            if let storageMessage = store.storageMessage {
                StorageMessageView(message: storageMessage)
            }

            results
            ShortcutFooter()
        }
        .padding(metrics.panelPadding)
        .frame(width: DesignSystem.panelWidth, height: DesignSystem.panelHeight)
        .background(panelBackground)
        .clipShape(.rect(cornerRadius: metrics.panelCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.panelCornerRadius)
                .strokeBorder(panelStroke)
        }
        .overlay(alignment: .bottom) {
            if let undoMessage = store.undoMessage {
                UndoBanner(
                    message: undoMessage,
                    onUndo: onUndo,
                    onDismiss: store.dismissUndoMessage
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 38)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .shadow(color: .black.opacity(metrics.shadowOpacity), radius: metrics.shadowRadius, x: 0, y: metrics.shadowY)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Clippa clipboard history"))
        .onAppear {
            isSearchFocused = true
        }
        .onDisappear {
            store.dismissUndoMessage()
        }
        .task(id: store.undoMessage) {
            guard let message = store.undoMessage else {
                return
            }
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            guard store.undoMessage == message else {
                return
            }
            animate {
                store.dismissUndoMessage()
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: store.undoMessage)
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            headerIcon

            VStack(alignment: .leading, spacing: 2) {
                headerTitle
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if store.pinnedItemCount > 0 {
                StatusBadge(
                    title: "\(store.pinnedItemCount)",
                    systemImage: "pin.fill"
                )
            }
        }
        .frame(height: metrics.headerHeight)
    }

    @ViewBuilder
    private var headerIcon: some View {
        if let bundleIdentifier = pasteDestination?.bundleIdentifier {
            ApplicationIconView(bundleIdentifier: bundleIdentifier, size: 36)
        } else {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var headerTitle: some View {
        if let pasteDestination {
            Text("Paste into \(pasteDestination.applicationName)")
                .font(.headline.weight(.semibold))
                .lineLimit(1)
        } else {
            Text("Clippa")
                .font(.headline.weight(.semibold))
        }
    }

    private var summaryText: String {
        let visibleCount = store.visibleItems.count
        guard visibleCount != store.items.count else {
            return "\(store.items.count) \(String(localized: "Items"))"
        }
        return "\(visibleCount) \(String(localized: "Shown")) / \(store.items.count) \(String(localized: "Items"))"
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(String(localized: "Search clipboard"), text: $store.searchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)

            if !store.searchQuery.isEmpty {
                Button {
                    store.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .accessibilityLabel(Text("Clear search"))
            }

            Button {
                isShowingSearchHelp.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Search help"))
            .popover(isPresented: $isShowingSearchHelp, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Tips")
                        .font(.headline)
                    Text("Combine words with these filters:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(verbatim: "kind:text  type:link  from:safari")
                        .font(.caption.monospaced())
                    Text(verbatim: "is:pinned  today  yesterday")
                        .font(.caption.monospaced())
                    Divider()
                    Text("Press ⌘Return to paste text or links as plain text.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(width: 310, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: DesignSystem.controlHeight)
        .background(searchBackground, in: .rect(cornerRadius: metrics.searchCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.searchCornerRadius)
                .strokeBorder(isSearchFocused ? Color.accentColor.opacity(0.34) : Color.primary.opacity(0.07))
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(ClipboardFilter.allCases) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: store.selectedFilter == filter,
                        count: count(for: filter)
                    ) {
                        animate {
                            store.selectedFilter = filter
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(height: DesignSystem.filterHeight)
    }

    private func count(for filter: ClipboardFilter) -> Int? {
        switch filter {
        case .all:
            let total = store.items.count
            return total == 0 ? nil : total
        case .pinned:
            return store.pinnedItemCount == 0 ? nil : store.pinnedItemCount
        case .text:
            return count(kind: .text)
        case .url:
            return count(kind: .url)
        case .image:
            return count(kind: .image)
        case .files:
            return count(kind: .files)
        }
    }

    private func count(kind: ClipboardItemKind) -> Int? {
        let total = store.items.count { $0.kind == kind }
        return total == 0 ? nil : total
    }

    @ViewBuilder
    private var results: some View {
        if store.visibleItems.isEmpty {
            EmptyClipboardView(isFiltering: store.selectedFilter != .all || !store.searchQuery.isEmpty)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        if store.selectedFilter == .all {
                            let pinnedItems = store.visibleItems.filter(\.isPinned)
                            let recentItems = store.visibleItems.filter { !$0.isPinned }
                            if !pinnedItems.isEmpty {
                                ResultSectionHeader(title: "Pinned")
                                clipboardRows(pinnedItems)
                            }
                            if !recentItems.isEmpty {
                                if !pinnedItems.isEmpty {
                                    ResultSectionHeader(title: "Recent")
                                }
                                clipboardRows(recentItems)
                            }
                        } else {
                            clipboardRows(store.visibleItems)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.automatic)
                .onChange(of: store.selectedItemID) { _, selectedID in
                    guard let selectedID else {
                        return
                    }
                    animate {
                        proxy.scrollTo(selectedID, anchor: .center)
                    }
                }
                .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: store.visibleItemsRevision)
            }
        }
    }

    private func clipboardRows(_ items: [ClipboardItem]) -> some View {
        ForEach(items) { item in
            ClipboardRow(
                item: item,
                loadImageData: store.imageData(for:),
                isSelected: item.id == store.selectedItemID,
                contrast: contrast,
                metrics: metrics,
                reduceMotion: reduceMotion,
                onSelect: {
                    animate { store.select(item) }
                },
                onPaste: {
                    animate { store.select(item) }
                    onPasteSelected()
                },
                onPasteAsPlainText: {
                    onPasteAsPlainText(item)
                },
                onCopy: {
                    onCopy(item)
                },
                onPreview: {
                    onPreview(item)
                },
                onOpen: {
                    onOpen(item)
                },
                onExtractText: {
                    onExtractText(item)
                },
                onTogglePin: {
                    animate { onTogglePin(item) }
                },
                onDelete: {
                    animate { onDelete(item) }
                }
            )
            .id(item.id)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func animate(_ changes: @escaping () -> Void) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(.snappy(duration: 0.16), changes)
        }
    }

    @ViewBuilder
    private var panelBackground: some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: metrics.panelCornerRadius))
        } else {
            Rectangle()
                .fill(.regularMaterial)
        }
    }

    private var panelStroke: Color {
        Color.primary.opacity(0.08)
    }

    private var searchBackground: some ShapeStyle {
        AnyShapeStyle(.thinMaterial)
    }
}

private struct ResultSectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.top, 3)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct ShortcutFooter: View {
    var body: some View {
        HStack(spacing: 12) {
            ShortcutHint(keys: "↑↓", action: "Select")
            ShortcutHint(keys: "↵", action: "Paste")
            ShortcutHint(keys: "⌘↵", action: "Plain Text")
            ShortcutHint(keys: "⌘Y", action: "Preview")
            ShortcutHint(keys: "⌘P", action: "Pin")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Keyboard shortcuts"))
    }
}

private struct ShortcutHint: View {
    let keys: String
    let action: LocalizedStringKey

    var body: some View {
        HStack(spacing: 4) {
            Text(verbatim: keys)
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.primary)
            Text(action)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }
}

private struct UndoBanner: View {
    let message: String
    let onUndo: @MainActor () -> Void
    let onDismiss: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(message)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Button("Undo", action: onUndo)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Dismiss"))
        }
        .padding(.leading, 12)
        .padding(.trailing, 7)
        .frame(height: 36)
        .background(.ultraThickMaterial, in: .capsule)
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.10))
        }
        .shadow(color: .black.opacity(0.16), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
    }
}

private struct StatusBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(Color.accentColor.opacity(0.12), in: .capsule)
            .accessibilityElement(children: .combine)
    }
}

private struct FilterChip: View {
    let filter: ClipboardFilter
    let isSelected: Bool
    let count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: filter.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                Text(filter.displayName)
                    .lineLimit(1)
                if let count {
                    Text("\(count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .frame(height: DesignSystem.filterHeight)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(chipBackground, in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var chipBackground: Color {
        isSelected ? Color.accentColor : Color.secondary.opacity(0.08)
    }
}

private struct StorageMessageView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.orange.opacity(0.12), in: .rect(cornerRadius: 10))
    }
}

private struct EmptyClipboardView: View {
    let isFiltering: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.10))
                Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle" : "doc.on.clipboard")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 62, height: 62)

            VStack(spacing: 3) {
                Text(isFiltering ? "No matches" : "Clipboard is empty")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(isFiltering ? "Try another search or filter." : "Copy something and it will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let loadImageData: @MainActor (ClipboardPayload) async throws -> Data
    let isSelected: Bool
    let contrast: ColorSchemeContrast
    let metrics: PanelMetrics
    let reduceMotion: Bool
    let onSelect: @MainActor () -> Void
    let onPaste: @MainActor () -> Void
    let onPasteAsPlainText: @MainActor () -> Void
    let onCopy: @MainActor () -> Void
    let onPreview: @MainActor () -> Void
    let onOpen: @MainActor () -> Void
    let onExtractText: @MainActor () -> Void
    let onTogglePin: @MainActor () -> Void
    let onDelete: @MainActor () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: metrics.rowSpacing) {
            rowContent

            rowActions
        }
        .frame(height: metrics.rowHeight)
        .padding(.horizontal, 8)
        .background(selectionBackground)
        .overlay {
            RoundedRectangle(cornerRadius: metrics.rowCornerRadius)
                .strokeBorder(rowStroke)
        }
        .clipShape(.rect(cornerRadius: metrics.rowCornerRadius))
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .snappy(duration: 0.14), value: isHovering)
        .animation(reduceMotion ? nil : .snappy(duration: 0.14), value: isSelected)
        .animation(reduceMotion ? nil : .snappy(duration: 0.14), value: item.isPinned)
        .contextMenu {
            Button(action: onPaste) {
                Label("Paste", systemImage: "return")
            }
            if item.payload.plainTextValue != nil {
                Button(action: onPasteAsPlainText) {
                    Label("Paste as Plain Text", systemImage: "textformat")
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button(action: onPreview) {
                Label("Quick Look", systemImage: "eye")
            }
            if item.kind == .url || item.kind == .files {
                Button(action: onOpen) {
                    Label("Open", systemImage: "arrow.up.forward.square")
                }
            }
            if item.kind == .image {
                Button(action: onExtractText) {
                    Label("Extract Text", systemImage: "text.viewfinder")
                }
            }
            Divider()
            Button(action: onTogglePin) {
                Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .onDrag {
            item.dragItemProvider(loadImageData: loadImageData)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityAction(named: Text("Select"), onSelect)
        .accessibilityAction(.default, onPaste)
    }

    @ViewBuilder
    private var rowActions: some View {
        if isHovering || isSelected || item.isPinned {
            HStack(spacing: 2) {
                RowIconButton(
                    systemImage: "eye",
                    accessibilityLabel: "Quick Look",
                    action: onPreview
                )

                if item.kind == .image {
                    RowIconButton(
                        systemImage: "text.viewfinder",
                        accessibilityLabel: "Extract Text",
                        action: onExtractText
                    )
                }

                RowIconButton(
                    systemImage: item.isPinned ? "pin.fill" : "pin",
                    accessibilityLabel: item.isPinned ? "Unpin" : "Pin",
                    isProminent: item.isPinned,
                    action: onTogglePin
                )

                RowIconButton(
                    systemImage: "trash",
                    accessibilityLabel: "Delete",
                    isDestructive: true,
                    action: onDelete
                )
            }
        } else {
            Color.clear
                .frame(width: hiddenActionWidth, height: DesignSystem.symbolButtonSize)
                .accessibilityHidden(true)
        }
    }

    private var hiddenActionWidth: CGFloat {
        let buttonCount: CGFloat = item.kind == .image ? 4 : 3
        return (DesignSystem.symbolButtonSize * buttonCount) + max(0, buttonCount - 1) * 2
    }

    private var rowContent: some View {
        HStack(spacing: metrics.rowSpacing) {
            ClipboardThumbnailView(
                item: item,
                loadImageData: loadImageData,
                size: metrics.iconWellSize,
                cornerRadius: metrics.thumbnailCornerRadius,
                showsPin: item.isPinned
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(rowTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                metadataLine
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 2)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .gesture(rowTapGesture)
        .help("Double-click to paste")
    }

    private var rowTapGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture(count: 1))
            .onEnded { gesture in
                switch gesture {
                case .first:
                    onPaste()
                case .second:
                    onSelect()
                }
            }
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            Label(item.kind.displayName, systemImage: item.kind.symbolName)
                .labelStyle(.titleAndIcon)

            if item.kind == .image {
                ClipboardImageInfoView(item: item)
            }

            if let bundleIdentifier = item.sourceBundleIdentifier,
               let source = item.cachedSourceName {
                ApplicationIconView(bundleIdentifier: bundleIdentifier, size: 13)
                Text(source)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text(relativeDate)
                .lineLimit(1)

            if item.kind == .files, case .files(let refs) = item.payload, refs.contains(where: { !$0.exists }) {
                Label("Unavailable", systemImage: "exclamationmark.triangle")
                    .labelStyle(.titleAndIcon)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var relativeDate: String {
        ClipboardFormatters.relativeDateTime.localizedString(for: item.lastUsedAt, relativeTo: Date())
    }

    private var rowTitle: String {
        if item.kind == .image {
            return String(localized: "Clipboard image")
        }
        return item.preview.isEmpty ? String(localized: "Empty text") : item.preview
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: metrics.rowCornerRadius)
                .fill(selectedFill)
        } else if isHovering {
            RoundedRectangle(cornerRadius: metrics.rowCornerRadius)
                .fill(Color.secondary.opacity(0.08))
        } else {
            RoundedRectangle(cornerRadius: metrics.rowCornerRadius)
                .fill(idleFill)
        }
    }

    private var selectedFill: Color {
        let baseOpacity = contrast == .increased ? 0.30 : 0.15
        return Color.accentColor.opacity(baseOpacity)
    }

    private var idleFill: Color {
        Color.primary.opacity(0.025)
    }

    private var rowStroke: Color {
        if isSelected {
            return Color.accentColor.opacity(0.26)
        }
        return Color.primary.opacity(0.05)
    }
}

private struct RowIconButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var isProminent = false
    var isDestructive = false
    let action: @MainActor () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: DesignSystem.symbolButtonSize, height: DesignSystem.symbolButtonSize)
                .foregroundStyle(foreground)
                .background(background, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .help(accessibilityLabel)
        .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        if isDestructive && isHovering {
            return .red
        }
        if isProminent {
            return .accentColor
        }
        return .secondary
    }

    private var background: Color {
        if isHovering {
            return isDestructive ? Color.red.opacity(0.12) : Color.accentColor.opacity(0.12)
        }
        return Color.clear
    }
}

@MainActor
private extension ClipboardItem {
    func dragItemProvider(
        loadImageData: @escaping @MainActor (ClipboardPayload) async throws -> Data
    ) -> NSItemProvider {
        switch payload {
        case .text(let text):
            return NSItemProvider(object: text as NSString)
        case .url(let url):
            return NSItemProvider(object: url as NSURL)
        case .image(let data, _):
            if let image = NSImage(data: data) {
                return NSItemProvider(object: image)
            }
            return NSItemProvider(object: preview as NSString)
        case .storedImage(_, let uti, _, _):
            let provider = NSItemProvider()
            provider.suggestedName = String(localized: "Clipboard image")
            provider.registerDataRepresentation(
                forTypeIdentifier: uti ?? "public.image",
                visibility: .all
            ) { completion in
                let progress = Progress(totalUnitCount: 1)
                Task { @MainActor in
                    defer { progress.completedUnitCount = 1 }
                    do {
                        completion(try await loadImageData(payload), nil)
                    } catch {
                        completion(nil, error)
                    }
                }
                return progress
            }
            return provider
        case .files(let references):
            if let url = references.first(where: \.exists)?.url {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider(object: preview as NSString)
        }
    }
}

#Preview("History Panel") {
    let store = ClipboardStore(persistenceEnabled: false)
    store.add(
        payload: .text("A private clipboard item ready to paste"),
        sourceBundleIdentifier: "com.apple.Notes"
    )
    store.add(
        payload: .url(URL(string: "https://clippa.app/docs")!),
        sourceBundleIdentifier: "com.apple.Safari"
    )
    if let first = store.items.first {
        store.togglePin(first)
    }
    return PanelView(
        store: store,
        pasteDestination: PanelPasteDestination(
            applicationName: "Notes",
            bundleIdentifier: "com.apple.Notes"
        ),
        onPasteSelected: {},
        onPasteAsPlainText: { _ in },
        onCopy: { _ in },
        onPreview: { _ in },
        onOpen: { _ in },
        onExtractText: { _ in },
        onTogglePin: { _ in },
        onDelete: { _ in },
        onUndo: {}
    )
}
