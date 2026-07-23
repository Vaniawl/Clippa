import AppKit
import ImageIO
import SwiftUI

enum DesignSystem {
    static let panelWidth: CGFloat = 560
    static let panelHeight: CGFloat = 430
    static let panelCornerRadius: CGFloat = 22
    static let rowHeight: CGFloat = 58
    static let controlHeight: CGFloat = 36
    static let rowCornerRadius: CGFloat = 12
    static let iconWellSize: CGFloat = 38
    static let symbolButtonSize: CGFloat = 28
    static let filterHeight: CGFloat = 30
    static let panelMetrics = PanelMetrics(
        panelPadding: 12,
        panelCornerRadius: panelCornerRadius,
        contentSpacing: 10,
        headerHeight: 38,
        rowHeight: rowHeight,
        rowCornerRadius: rowCornerRadius,
        rowSpacing: 10,
        iconWellSize: iconWellSize,
        thumbnailCornerRadius: 8,
        searchCornerRadius: 10,
        shadowOpacity: 0.18,
        shadowRadius: 28,
        shadowY: 18
    )
}

struct PanelMetrics {
    let panelPadding: CGFloat
    let panelCornerRadius: CGFloat
    let contentSpacing: CGFloat
    let headerHeight: CGFloat
    let rowHeight: CGFloat
    let rowCornerRadius: CGFloat
    let rowSpacing: CGFloat
    let iconWellSize: CGFloat
    let thumbnailCornerRadius: CGFloat
    let searchCornerRadius: CGFloat
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowY: CGFloat
}

struct ClipboardThumbnailView: View {
    let item: ClipboardItem
    var size: CGFloat
    var cornerRadius: CGFloat = 8
    var showsPin = false
    @State private var image: NSImage?

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
        .task(id: item.payloadHash) {
            guard case .image(let data, _) = item.payload else {
                image = nil
                return
            }
            image = await ClipboardImageCache.image(for: item.payloadHash, data: data)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch item.payload {
        case .image:
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .background(Color.secondary.opacity(0.08))
            } else {
                fallbackIcon(symbol: "photo", color: .secondary)
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

    static func image(for key: String, data: Data) async -> NSImage? {
        let cacheKey = key as NSString
        if let image = cache.object(forKey: cacheKey) {
            return image
        }
        let cgImage = await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                return nil as CGImage?
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 256
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }.value
        guard let cgImage else {
            return nil
        }
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: cacheKey, cost: min(data.count, 256 * 256 * 4))
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

struct ApplicationIconView: View {
    let bundleIdentifier: String
    let size: CGFloat

    var body: some View {
        Image(nsImage: ApplicationIconCache.icon(for: bundleIdentifier))
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

@MainActor
enum ApplicationIconCache {
    private static let icons = NSCache<NSString, NSImage>()

    static func icon(for bundleIdentifier: String) -> NSImage {
        let key = bundleIdentifier as NSString
        if let cached = icons.object(forKey: key) {
            return cached
        }
        let icon: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        icons.setObject(icon, forKey: key)
        return icon
    }
}

@MainActor
enum ClipboardFormatters {
    static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    static let relativeDateTime: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .short
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
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
