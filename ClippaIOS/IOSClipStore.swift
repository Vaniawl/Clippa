import Foundation
import Observation
import UIKit

@MainActor
protocol IOSPasteboard: AnyObject {
    var string: String? { get set }
    var url: URL? { get set }
    var image: UIImage? { get set }
}

extension UIPasteboard: IOSPasteboard {}

@MainActor
@Observable
final class IOSClipStore {
    private(set) var clips: [IOSClip]
    var selectedFilter: IOSClipFilter = .all
    var lastCopyMessage: String?

    private let defaults: UserDefaults
    private let pasteboard: IOSPasteboard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let clipsKey = "clippa.ios.clips"
    private let maxClips = 200

    init(defaults: UserDefaults = .standard, pasteboard: IOSPasteboard = UIPasteboard.general) {
        self.defaults = defaults
        self.pasteboard = pasteboard
        if let data = defaults.data(forKey: clipsKey),
           let decoded = try? decoder.decode([IOSClip].self, from: data) {
            self.clips = decoded
        } else {
            self.clips = []
        }
    }

    func filteredClips(query: String) -> [IOSClip] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return clips
            .filter { clip in
                switch selectedFilter {
                case .all: true
                case .pinned: clip.isPinned
                case .text: clip.kind == .text
                case .link: clip.kind == .link
                case .image: clip.kind == .image
                }
            }
            .filter { clip in
                trimmedQuery.isEmpty || clip.searchText.localizedCaseInsensitiveContains(trimmedQuery)
            }
            .sorted { left, right in
                if left.isPinned != right.isPinned {
                    return left.isPinned
                }
                return left.createdAt > right.createdAt
            }
    }

    @discardableResult
    func saveCurrentPasteboard() -> Bool {
        if let image = pasteboard.image,
           let data = image.pngData() {
            upsert(
                IOSClip(
                    kind: .image,
                    title: "Clipboard image",
                    detail: "\(Int(image.size.width)) x \(Int(image.size.height))",
                    imageData: data
                )
            )
            lastCopyMessage = "Saved current image."
            return true
        }

        if let url = pasteboard.url {
            upsert(
                IOSClip(
                    kind: .link,
                    title: url.host(percentEncoded: false) ?? url.absoluteString,
                    detail: url.absoluteString,
                    content: url.absoluteString
                )
            )
            lastCopyMessage = "Saved current link."
            return true
        }

        if let text = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                upsert(
                    IOSClip(
                        kind: .link,
                        title: url.host(percentEncoded: false) ?? text.previewLine(limit: 64),
                        detail: text,
                        content: text
                    )
                )
            } else {
                upsert(
                    IOSClip(
                        kind: .text,
                        title: text.previewLine(limit: 72),
                        detail: text.previewLine(limit: 140),
                        content: text
                    )
                )
            }
            lastCopyMessage = "Saved current text."
            return true
        }

        lastCopyMessage = "Clipboard is empty."
        return false
    }

    @discardableResult
    func copy(_ clip: IOSClip) -> Bool {
        switch clip.kind {
        case .text:
            guard let content = clip.content else { return false }
            pasteboard.string = content
        case .link:
            guard let content = clip.content else { return false }
            if let url = URL(string: content) {
                pasteboard.url = url
            } else {
                pasteboard.string = content
            }
        case .image:
            guard let data = clip.imageData,
                  let image = UIImage(data: data)
            else { return false }
            pasteboard.image = image
        }

        if let index = clips.firstIndex(where: { $0.id == clip.id }) {
            clips[index].lastCopiedAt = Date()
        }
        persist()
        lastCopyMessage = "Copied. Go back and paste."
        return true
    }

    func togglePin(_ clip: IOSClip) {
        guard let index = clips.firstIndex(where: { $0.id == clip.id }) else {
            return
        }
        clips[index].isPinned.toggle()
        persist()
    }

    func delete(_ clip: IOSClip) {
        clips.removeAll { $0.id == clip.id }
        persist()
    }

    func clearMessage() {
        lastCopyMessage = nil
    }

    private func upsert(_ clip: IOSClip) {
        clips.removeAll { existing in
            existing.kind == clip.kind &&
            existing.content == clip.content &&
            existing.imageData == clip.imageData
        }
        clips.insert(clip, at: 0)
        if clips.count > maxClips {
            clips = Array(clips.prefix(maxClips))
        }
        persist()
    }

    private func persist() {
        guard let data = try? encoder.encode(clips) else {
            return
        }
        defaults.set(data, forKey: clipsKey)
    }
}

enum IOSClipFilter: String, CaseIterable, Identifiable {
    case all
    case pinned
    case text
    case link
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .pinned: "Pinned"
        case .text: "Text"
        case .link: "Links"
        case .image: "Images"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "tray.full"
        case .pinned: "pin"
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        }
    }
}

private extension String {
    func previewLine(limit: Int) -> String {
        let collapsed = split(whereSeparator: \.isNewline).joined(separator: " ")
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }
        let end = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return "\(trimmed[..<end])..."
    }
}
