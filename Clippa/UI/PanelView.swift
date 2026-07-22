import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var store: ClipboardStore
    var notice: String?
    var onPasteSelected: @MainActor () -> Void
    var onTogglePin: @MainActor () -> Void
    var onDelete: @MainActor () -> Void
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
            if let notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
            Text("⌘⇧V")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(height: DesignSystem.controlHeight)
    }

    private var filterRow: some View {
        Picker("Filter", selection: $store.selectedFilter) {
            ForEach(ClipboardFilter.allCases) { filter in
                Text(filter.displayName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .accessibilityLabel(Text("Filter"))
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
                            contrast: contrast
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
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let contrast: ColorSchemeContrast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.kind.symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview.isEmpty ? String(localized: "Empty text") : item.preview)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(item.kind.displayName)
                    Text(item.createdAt, style: .relative)
                    if item.kind == .files, case .files(let refs) = item.payload, refs.contains(where: { !$0.exists }) {
                        Text("Unavailable")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Pinned"))
            }
        }
        .frame(height: DesignSystem.rowHeight)
        .padding(.horizontal, 8)
        .background(selectionBackground)
        .clipShape(.rect(cornerRadius: 7))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 7)
                .fill(contrast == .increased ? Color.accentColor.opacity(0.28) : Color.accentColor.opacity(0.16))
        }
    }
}
