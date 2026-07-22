import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var store: ClipboardStore
    var notice: String?
    var isAutoPasteReady: Bool
    var showShortcutText: String
    var pinShortcutText: String
    var onPasteSelected: @MainActor () -> Void
    var onCopy: @MainActor (ClipboardItem) -> Void
    var onOpen: @MainActor (ClipboardItem) -> Void
    var onReveal: @MainActor (ClipboardItem) -> Void
    var onTogglePin: @MainActor (ClipboardItem) -> Void
    var onDelete: @MainActor (ClipboardItem) -> Void
    var onClose: @MainActor () -> Void
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 12) {
            headerRow
            searchRow
            filterRow
            Divider()
            results
            if notice != nil {
                statusRow
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(14)
        .frame(width: DesignSystem.panelWidth, height: DesignSystem.panelHeight)
        .background(panelBackground)
        .clipShape(.rect(cornerRadius: DesignSystem.panelCornerRadius))
        .task {
            searchFocused = true
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: store.searchQuery.isEmpty)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Clippa clipboard history"))
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "paperclip.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("Clippa")
                    .font(.headline)
                Text("\(store.items.count) \(String(localized: "Items"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if !isAutoPasteReady {
                statusBadge(
                    title: String(localized: "Copy only"),
                    symbol: "doc.on.doc",
                    isProminent: false
                )
            }
        }
        .frame(height: 34)
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard", text: $store.searchQuery)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .font(.body)
                .accessibilityLabel(Text("Search clipboard"))
            if !store.searchQuery.isEmpty {
                Button {
                    animate { store.searchQuery = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Clear search"))
                .accessibilityLabel(Text("Clear search"))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            Text(showShortcutText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.tertiary.opacity(0.14), in: .rect(cornerRadius: 5))
        }
        .frame(height: DesignSystem.controlHeight)
        .padding(.horizontal, 12)
        .background(Color.secondary.opacity(0.10), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator.opacity(0.45))
        }
    }

    private var filterRow: some View {
        HStack(spacing: 4) {
            ForEach(ClipboardFilter.allCases) { filter in
                Button {
                    animate { store.selectedFilter = filter }
                } label: {
                    ViewThatFits(in: .horizontal) {
                        Label(filter.displayName, systemImage: filter.symbolName)
                            .labelStyle(.titleAndIcon)
                        Image(systemName: filter.symbolName)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.selectedFilter == filter ? Color.accentColor : Color.secondary)
                .background(filterBackground(filter))
                .clipShape(.rect(cornerRadius: 7))
                .help(filter.displayName)
                .accessibilityLabel(Text(filter.displayName))
                .accessibilityAddTraits(store.selectedFilter == filter ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(.tertiary.opacity(0.10), in: .rect(cornerRadius: 10))
        .accessibilityLabel(Text("Filter"))
        .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: store.selectedFilter)
    }

    @ViewBuilder
    private func filterBackground(_ filter: ClipboardFilter) -> some View {
        if store.selectedFilter == filter {
            RoundedRectangle(cornerRadius: 7)
                .fill(contrast == .increased ? Color.accentColor.opacity(0.26) : Color.accentColor.opacity(0.14))
        }
    }

    @ViewBuilder
    private var results: some View {
        if store.visibleItems.isEmpty {
            VStack(spacing: 6) {
                Text("No matching clipboard items")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Copied text, links, images, and files will appear here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.visibleItems.prefix(100)) { item in
                        ClipboardRow(
                            item: item,
                            isSelected: item.id == store.selectedItemID,
                            contrast: contrast,
                            reduceMotion: reduceMotion,
                            pinShortcutText: pinShortcutText,
                            onPaste: {
                                animate { store.select(item) }
                                onPasteSelected()
                            },
                            onCopy: {
                                onCopy(item)
                            },
                            onOpen: {
                                onOpen(item)
                            },
                            onReveal: {
                                onReveal(item)
                            },
                            onTogglePin: {
                                onTogglePin(item)
                            },
                            onDelete: {
                                onDelete(item)
                            }
                        )
                        .contentShape(.rect)
                        .onTapGesture {
                            animate { store.select(item) }
                            onPasteSelected()
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.automatic)
            .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: store.visibleItems.map(\.id))
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
                .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.panelCornerRadius))
        } else {
            Rectangle()
                .fill(.regularMaterial)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            if let notice {
                Text(notice)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 18)
    }

    private func statusBadge(title: String, symbol: String, isProminent: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
            Text(title)
                .font(.caption2)
        }
        .foregroundStyle(isProminent ? Color.orange : Color.secondary)
        .lineLimit(1)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let contrast: ColorSchemeContrast
    let reduceMotion: Bool
    let pinShortcutText: String
    let onPaste: @MainActor () -> Void
    let onCopy: @MainActor () -> Void
    let onOpen: @MainActor () -> Void
    let onReveal: @MainActor () -> Void
    let onTogglePin: @MainActor () -> Void
    let onDelete: @MainActor () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            ClipboardThumbnailView(item: item, size: DesignSystem.iconWellSize, showsPin: true)

            VStack(alignment: .leading, spacing: 3) {
                Text(rowTitle)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                metadataLine
            }
            Spacer(minLength: 8)
            rowActions
                .opacity(isSelected || isHovering ? 1 : (item.isPinned ? 0.75 : 0))
                .scaleEffect(isSelected || isHovering ? 1 : 0.96)
        }
        .onHover { isHovering = $0 }
        .frame(height: DesignSystem.rowHeight)
        .padding(.horizontal, 10)
        .background(selectionBackground)
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.rowCornerRadius)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.26) : Color.clear)
        }
        .clipShape(.rect(cornerRadius: DesignSystem.rowCornerRadius))
        .animation(reduceMotion ? nil : .snappy(duration: 0.14), value: isHovering)
        .animation(reduceMotion ? nil : .snappy(duration: 0.14), value: isSelected)
        .contextMenu {
            Button("Paste") {
                onPaste()
            }
            Button("Copy") {
                onCopy()
            }
            Divider()
            if canOpen {
                Button(openTitle) {
                    onOpen()
                }
            }
            if canReveal {
                Button("Reveal in Finder") {
                    onReveal()
                }
            }
            Button(item.isPinned ? "Unpin" : "Pin") {
                onTogglePin()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            if item.kind != .image {
                Text(item.kind.displayName)
            }
            if case .image = item.payload {
                ClipboardImageInfoView(item: item)
            }
            if let source = sourceName {
                Text(source)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if item.kind == .files, case .files(let refs) = item.payload, refs.contains(where: { !$0.exists }) {
                Text("Unavailable")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var rowActions: some View {
        HStack(spacing: 2) {
            Button {
                onCopy()
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: DesignSystem.symbolButtonSize, height: DesignSystem.symbolButtonSize)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(String(localized: "Copy"))
            .accessibilityLabel(Text("Copy"))

            Button {
                onTogglePin()
            } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .frame(width: DesignSystem.symbolButtonSize, height: DesignSystem.symbolButtonSize)
            }
            .buttonStyle(.plain)
            .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
            .help("\(item.isPinned ? String(localized: "Unpin") : String(localized: "Pin")) \(pinShortcutText)")
            .accessibilityLabel(Text(item.isPinned ? "Unpin" : "Pin"))

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .frame(width: DesignSystem.symbolButtonSize, height: DesignSystem.symbolButtonSize)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(String(localized: "Delete"))
            .accessibilityLabel(Text("Delete"))
        }
    }

    private var sourceName: String? {
        guard let identifier = item.sourceBundleIdentifier else {
            return nil
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            return identifier
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    private var canOpen: Bool {
        switch item.payload {
        case .url:
            true
        case .files(let refs):
            refs.contains(where: \.exists)
        case .text, .image:
            false
        }
    }

    private var canReveal: Bool {
        if case .files(let refs) = item.payload {
            refs.contains(where: \.exists)
        } else {
            false
        }
    }

    private var openTitle: String {
        switch item.payload {
        case .url:
            String(localized: "Open URL")
        case .files:
            String(localized: "Open File")
        case .text, .image:
            String(localized: "Open")
        }
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
            RoundedRectangle(cornerRadius: DesignSystem.rowCornerRadius)
                .fill(contrast == .increased ? Color.accentColor.opacity(0.28) : Color.accentColor.opacity(0.16))
        } else if isHovering {
            RoundedRectangle(cornerRadius: DesignSystem.rowCornerRadius)
                .fill(Color.secondary.opacity(0.08))
        }
    }
}
