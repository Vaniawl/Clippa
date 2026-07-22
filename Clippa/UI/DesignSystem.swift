import AppKit
import SwiftUI

enum DesignSystem {
    static let panelWidth: CGFloat = 560
    static let panelHeight: CGFloat = 360
    static let panelCornerRadius: CGFloat = 20
    static let rowHeight: CGFloat = 52
    static let controlHeight: CGFloat = 32
    static let rowCornerRadius: CGFloat = 8
    static let iconWellSize: CGFloat = 36
    static let symbolButtonSize: CGFloat = 24
}

struct ClipboardThumbnailView: View {
    let item: ClipboardItem
    var size: CGFloat
    var cornerRadius: CGFloat = 8
    var showsPin = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnail
                .frame(width: size, height: size)
                .clipShape(.rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.primary.opacity(0.08))
                }

            if showsPin, item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: max(8, size * 0.22), weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(3)
                    .background(.regularMaterial, in: .circle)
                    .offset(x: 4, y: -4)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch item.payload {
        case .image(let data, _):
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .background(Color.secondary.opacity(0.08))
            } else {
                fallbackIcon(symbol: "photo.badge.exclamationmark", color: .orange)
            }
        case .text:
            fallbackIcon(symbol: item.kind.symbolName, color: .secondary)
        case .url:
            fallbackIcon(symbol: item.kind.symbolName, color: .blue)
        case .files:
            fallbackIcon(symbol: item.kind.symbolName, color: .orange)
        }
    }

    private func fallbackIcon(symbol: String, color: Color) -> some View {
        ZStack {
            color.opacity(0.12)
            Image(systemName: symbol)
                .font(.system(size: max(13, size * 0.42), weight: .medium))
                .foregroundStyle(color)
        }
    }
}

struct ClipboardImageInfoView: View {
    let item: ClipboardItem

    var body: some View {
        if case .image(let data, let uti) = item.payload {
            HStack(spacing: 6) {
                Label(imageDescription(data: data, uti: uti), systemImage: "info.circle")
                    .labelStyle(.titleAndIcon)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private func imageDescription(data: Data, uti: String?) -> String {
        let byteCount = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        let dimensions = NSImage(data: data).map { image in
            "\(Int(image.size.width)) x \(Int(image.size.height))"
        }
        return [String(localized: "Image"), dimensions, byteCount, uti].compactMap { $0 }.joined(separator: " / ")
    }
}
