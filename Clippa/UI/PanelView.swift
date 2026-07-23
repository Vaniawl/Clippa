import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var store: ClipboardStore
    @Bindable var settings: AppSettings
    var onPasteSelected: @MainActor () -> Void
    var onCopy: @MainActor (ClipboardItem) -> Void
    var onPreview: @MainActor (ClipboardItem) -> Void
    var onOpen: @MainActor (ClipboardItem) -> Void
    var onTogglePin: @MainActor (ClipboardItem) -> Void
    var onDelete: @MainActor (ClipboardItem) -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var isSearchFocused: Bool

    private var design: PanelDesign { settings.panelDesign }
    private var metrics: PanelDesignMetrics { design.metrics }

    var body: some View {
        VStack(spacing: metrics.contentSpacing) {
            headerRow
            searchField
            filterBar

            if let storageMessage = store.storageMessage {
                StorageMessageView(message: storageMessage)
            }

            results
        }
        .padding(metrics.panelPadding)
        .frame(width: DesignSystem.panelWidth, height: DesignSystem.panelHeight)
        .background(panelBackground)
        .clipShape(.rect(cornerRadius: metrics.panelCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: metrics.panelCornerRadius)
                .strokeBorder(panelStroke)
        }
        .shadow(color: .black.opacity(metrics.shadowOpacity), radius: metrics.shadowRadius, x: 0, y: metrics.shadowY)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Clippa clipboard history"))
        .onAppear {
            isSearchFocused = true
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                Image(systemName: "paperclip")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Clippa")
                    .font(.headline.weight(.semibold))
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if settings.isMonitoringPaused {
                StatusBadge(
                    title: String(localized: "Paused"),
                    systemImage: "pause.fill",
                    design: design
                )
            }

            if store.pinnedItemCount > 0 {
                StatusBadge(
                    title: "\(store.pinnedItemCount)",
                    systemImage: "pin.fill",
                    design: design
                )
            }

            PanelDesignMenu(selection: $settings.panelDesign)
        }
        .frame(height: metrics.headerHeight)
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
            store.items.isEmpty ? nil : store.items.count
        case .pinned:
            store.pinnedItemCount == 0 ? nil : store.pinnedItemCount
        case .text:
            count(kind: .text)
        case .url:
            count(kind: .url)
        case .image:
            count(kind: .image)
        case .files:
            count(kind: .files)
        }
    }

    private func count(kind: ClipboardItemKind) -> Int? {
        let total = store.items.filter { $0.kind == kind }.count
        return total == 0 ? nil : total
    }

    @ViewBuilder
    private var results: some View {
        if store.visibleItems.isEmpty {
            EmptyClipboardView(isFiltering: store.selectedFilter != .all || !store.searchQuery.isEmpty)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(store.visibleItems) { item in
                            ClipboardRow(
                                item: item,
                                isSelected: item.id == store.selectedItemID,
                                contrast: contrast,
                                design: design,
                                metrics: metrics,
                                reduceMotion: reduceMotion,
                                onPaste: {
                                    animate { store.select(item) }
                                    onPasteSelected()
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

    private func animate(_ changes: @escaping () -> Void) {
        if reduceMotion {
            changes()
        } else {
            withAnimation(.snappy(duration: 0.16), changes)
        }
    }

    @ViewBuilder
    private var panelBackground: some View {
        if design == .compact {
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
        } else if #available(macOS 26.0, *), !reduceTransparency {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: metrics.panelCornerRadius))
        } else {
            Rectangle()
                .fill(design == .focus ? .ultraThinMaterial : .regularMaterial)
        }
    }

    private var panelStroke: Color {
        switch design {
        case .glass:
            Color.primary.opacity(0.08)
        case .focus:
            Color.accentColor.opacity(0.18)
        case .compact:
            Color.primary.opacity(0.12)
        }
    }

    private var searchBackground: some ShapeStyle {
        switch design {
        case .glass:
            AnyShapeStyle(.thinMaterial)
        case .focus:
            AnyShapeStyle(Color.accentColor.opacity(0.08))
        case .compact:
            AnyShapeStyle(Color.secondary.opacity(0.07))
        }
    }
}

private struct StatusBadge: View {
    let title: String
    let systemImage: String
    let design: PanelDesign

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(Color.accentColor.opacity(design == .focus ? 0.18 : 0.12), in: .capsule)
            .accessibilityElement(children: .combine)
    }
}

private struct PanelDesignMenu: View {
    @Binding var selection: PanelDesign

    var body: some View {
        Menu {
            Picker("Appearance", selection: $selection) {
                ForEach(PanelDesign.allCases) { design in
                    Label(design.displayName, systemImage: design.symbolName)
                        .tag(design)
                }
            }
        } label: {
            Image(systemName: selection.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: DesignSystem.symbolButtonSize, height: DesignSystem.symbolButtonSize)
                .foregroundStyle(.secondary)
                .background(Color.secondary.opacity(0.08), in: .circle)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Appearance"))
        .help("Appearance")
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
    let isSelected: Bool
    let contrast: ColorSchemeContrast
    let design: PanelDesign
    let metrics: PanelDesignMetrics
    let reduceMotion: Bool
    let onPaste: @MainActor () -> Void
    let onCopy: @MainActor () -> Void
    let onPreview: @MainActor () -> Void
    let onOpen: @MainActor () -> Void
    let onTogglePin: @MainActor () -> Void
    let onDelete: @MainActor () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: metrics.rowSpacing) {
            if design == .focus {
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 3, height: metrics.rowHeight - 18)
                    .accessibilityHidden(true)
            }

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
            Divider()
            Button(action: onTogglePin) {
                Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .onDrag {
            item.dragItemProvider
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
                .frame(width: (DesignSystem.symbolButtonSize * 3) + 4, height: DesignSystem.symbolButtonSize)
                .accessibilityHidden(true)
        }
    }

    private var rowContent: some View {
        HStack(spacing: metrics.rowSpacing) {
            ClipboardThumbnailView(
                item: item,
                size: metrics.iconWellSize,
                cornerRadius: metrics.thumbnailCornerRadius,
                showsPin: item.isPinned
            )

            VStack(alignment: .leading, spacing: design == .compact ? 2 : 4) {
                Text(rowTitle)
                    .font(design == .compact ? .caption.weight(.medium) : .subheadline.weight(.medium))
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
        .onTapGesture(perform: onPaste)
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            Label(item.kind.displayName, systemImage: item.kind.symbolName)
                .labelStyle(.titleAndIcon)

            if case .image = item.payload {
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
                .fill(Color.secondary.opacity(design == .compact ? 0.06 : 0.08))
        } else {
            RoundedRectangle(cornerRadius: metrics.rowCornerRadius)
                .fill(idleFill)
        }
    }

    private var selectedFill: Color {
        let baseOpacity = contrast == .increased ? 0.30 : 0.15
        switch design {
        case .glass:
            return Color.accentColor.opacity(baseOpacity)
        case .focus:
            return Color.accentColor.opacity(contrast == .increased ? 0.22 : 0.10)
        case .compact:
            return Color.accentColor.opacity(contrast == .increased ? 0.26 : 0.12)
        }
    }

    private var idleFill: Color {
        switch design {
        case .glass:
            return Color.primary.opacity(0.025)
        case .focus:
            return Color.clear
        case .compact:
            return Color.secondary.opacity(0.035)
        }
    }

    private var rowStroke: Color {
        if isSelected {
            return Color.accentColor.opacity(design == .focus ? 0.32 : 0.26)
        }
        return design == .compact ? Color.primary.opacity(0.06) : Color.primary.opacity(0.05)
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
    var dragItemProvider: NSItemProvider {
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
        case .files(let references):
            if let url = references.first(where: \.exists)?.url {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider(object: preview as NSString)
        }
    }
}
