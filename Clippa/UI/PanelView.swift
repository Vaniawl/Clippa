import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var store: ClipboardStore
    var notice: String?
    var onPasteSelected: @MainActor () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 8) {
            headerRow
            Divider()
            results
            if let notice {
                Text(notice)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .padding(10)
        .frame(width: DesignSystem.panelWidth, height: DesignSystem.panelHeight)
        .background(panelBackground)
        .clipShape(.rect(cornerRadius: DesignSystem.panelCornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Clippa clipboard history"))
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "paperclip.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("Clippa")
                    .font(.callout.weight(.semibold))
                Text("\(store.items.count) \(String(localized: "Items"))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 30)
    }

    @ViewBuilder
    private var results: some View {
        if store.visibleItems.isEmpty {
            VStack(spacing: 6) {
                Text("Clipboard is empty")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Copy something and it will appear here.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(store.visibleItems) { item in
                            ClipboardRow(
                                item: item,
                                isSelected: item.id == store.selectedItemID,
                                contrast: contrast,
                                reduceMotion: reduceMotion
                            )
                            .id(item.id)
                            .contentShape(.rect)
                            .onTapGesture {
                                animate { store.select(item) }
                                onPasteSelected()
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.vertical, 1)
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
    let reduceMotion: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            ClipboardThumbnailView(item: item, size: DesignSystem.iconWellSize, showsPin: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(rowTitle)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                metadataLine
            }

            Spacer(minLength: 8)
        }
        .onHover { isHovering = $0 }
        .frame(height: DesignSystem.rowHeight)
        .padding(.horizontal, 8)
        .background(selectionBackground)
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.rowCornerRadius)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.26) : Color.clear)
        }
        .clipShape(.rect(cornerRadius: DesignSystem.rowCornerRadius))
        .animation(reduceMotion ? nil : .snappy(duration: 0.14), value: isHovering)
        .animation(reduceMotion ? nil : .snappy(duration: 0.14), value: isSelected)
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
            if let source = item.cachedSourceName {
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
