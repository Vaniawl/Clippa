import AppKit
import SwiftUI

enum DesignSystem {
    static let panelWidth: CGFloat = 540
    static let panelHeight: CGFloat = 360
    static let panelCornerRadius: CGFloat = 18
    static let rowHeight: CGFloat = 48
    static let controlHeight: CGFloat = 36
    static let rowCornerRadius: CGFloat = 8
    static let iconWellSize: CGFloat = 32
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
            if let image = ClipboardImageCache.image(for: item.payloadHash, data: data) {
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
        if let metadata = item.imageMetadata {
            HStack(spacing: 6) {
                Label(imageDescription(metadata: metadata), systemImage: "info.circle")
                    .labelStyle(.titleAndIcon)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private func imageDescription(metadata: ClipboardImageMetadata) -> String {
        let byteCount = ClipboardFormatters.byteCount.string(fromByteCount: Int64(metadata.byteCount))
        return [
            String(localized: "Clipboard image"),
            metadata.dimensionsText,
            byteCount,
            metadata.uti
        ].compactMap { $0 }.joined(separator: " / ")
    }
}

@MainActor
enum ClipboardImageCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 120
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func image(for key: String, data: Data) -> NSImage? {
        let cacheKey = key as NSString
        if let image = cache.object(forKey: cacheKey) {
            return image
        }
        guard let image = NSImage(data: data) else {
            return nil
        }
        cache.setObject(image, forKey: cacheKey, cost: data.count)
        return image
    }
}

@MainActor
enum ApplicationDisplayNameCache {
    private static var namesByBundleIdentifier: [String: String] = [:]

    static func displayName(for bundleIdentifier: String) -> String {
        if let cached = namesByBundleIdentifier[bundleIdentifier] {
            return cached
        }
        let name: String
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            name = FileManager.default.displayName(atPath: url.path)
        } else {
            name = bundleIdentifier
        }
        namesByBundleIdentifier[bundleIdentifier] = name
        return name
    }
}

@MainActor
enum ClipboardFormatters {
    static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

@MainActor
extension ClipboardItem {
    var cachedSourceName: String? {
        guard let sourceBundleIdentifier else {
            return nil
        }
        return ApplicationDisplayNameCache.displayName(for: sourceBundleIdentifier)
    }
}
