import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var store: ClipboardStore
    var notice: String?
    var isMonitoringPaused: Bool
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
        VStack(spacing: 8) {
            searchRow
            filterRow
            Divider()
            results
            statusRow
        }
        .padding(12)
        .frame(width: DesignSystem.panelWidth, height: DesignSystem.panelHeight)
        .background(panelBackground)
        .clipShape(.rect(cornerRadius: DesignSystem.panelCornerRadius))
        .task {
            searchFocused = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Clippa clipboard history"))
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
                    store.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Clear search"))
                .accessibilityLabel(Text("Clear search"))
            }
            Text(showShortcutText)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.tertiary.opacity(0.14), in: .rect(cornerRadius: 5))
        }
        .frame(height: DesignSystem.controlHeight)
    }

    private var filterRow: some View {
        HStack(spacing: 4) {
            ForEach(ClipboardFilter.allCases) { filter in
                Button {
                    store.selectedFilter = filter
                } label: {
                    Image(systemName: filter.symbolName)
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
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
        .background(.tertiary.opacity(0.10), in: .rect(cornerRadius: 9))
        .accessibilityLabel(Text("Filter"))
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
                LazyVStack(spacing: 0) {
                    ForEach(store.visibleItems.prefix(100)) { item in
                        ClipboardRow(
                            item: item,
                            isSelected: item.id == store.selectedItemID,
                            contrast: contrast,
                            pinShortcutText: pinShortcutText,
                            onPaste: {
                                store.select(item)
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
                            store.select(item)
                            onPasteSelected()
                        }
                    }
                }
            }
            .scrollIndicators(.automatic)
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
            statusBadge(
                title: isMonitoringPaused ? String(localized: "Paused") : String(localized: "Watching"),
                symbol: isMonitoringPaused ? "pause.fill" : "checkmark.circle.fill",
                isProminent: isMonitoringPaused
            )
            statusBadge(
                title: isAutoPasteReady ? String(localized: "Auto-paste ready") : String(localized: "Copy only"),
                symbol: isAutoPasteReady ? "checkmark.circle.fill" : "doc.on.doc",
                isProminent: false
            )
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
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview.isEmpty ? String(localized: "Empty text") : item.preview)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(item.kind.displayName)
                    Text(item.createdAt, style: .relative)
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
            Spacer(minLength: 8)
            rowActions
                .opacity(isSelected || isHovering ? 1 : (item.isPinned ? 0.75 : 0))
        }
        .onHover { isHovering = $0 }
        .frame(height: DesignSystem.rowHeight)
        .padding(.horizontal, 8)
        .background(selectionBackground)
        .clipShape(.rect(cornerRadius: DesignSystem.rowCornerRadius))
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

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(iconBackground)
            Image(systemName: item.kind.symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: DesignSystem.iconWellSize, height: DesignSystem.iconWellSize)
    }

    private var iconBackground: Color {
        switch item.kind {
        case .text:
            Color.secondary.opacity(0.10)
        case .url:
            Color.blue.opacity(0.12)
        case .image:
            Color.green.opacity(0.12)
        case .files:
            Color.orange.opacity(0.12)
        }
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

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: DesignSystem.rowCornerRadius)
                .fill(contrast == .increased ? Color.accentColor.opacity(0.28) : Color.accentColor.opacity(0.16))
        }
    }
}
