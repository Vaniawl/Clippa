import Foundation
import Observation
import UIKit

@MainActor
protocol IOSPasteboard: AnyObject {
    var string: String? { get set }
    var url: URL? { get set }
    var image: UIImage? { get set }
    var changeCount: Int { get }
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
    private var lastObservedPasteboardChangeCount: Int?
    private var lastWrittenPasteboardSignature: IOSClipSignature?

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
        let parsedQuery = IOSClipSearchQuery(query)
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
                parsedQuery.matches(clip)
            }
            .sorted { left, right in
                if left.isPinned != right.isPinned {
                    return left.isPinned
                }
                return left.createdAt > right.createdAt
            }
    }

    var pinnedCount: Int {
        clips.filter(\.isPinned).count
    }

    var unpinnedCount: Int {
        clips.count - pinnedCount
    }

    var mostRecentClip: IOSClip? {
        clips.max { left, right in
            left.createdAt < right.createdAt
        }
    }

    @discardableResult
    func saveCurrentPasteboard() -> Bool {
        let result = captureCurrentPasteboard(showMessage: true, skipOwnWrites: false)
        return result.didSave
    }

    @discardableResult
    func captureCurrentPasteboardIfNeeded(showMessage: Bool = false) -> IOSPasteboardCaptureResult {
        let currentChangeCount = pasteboard.changeCount
        if lastObservedPasteboardChangeCount == currentChangeCount {
            return .unchanged
        }
        return captureCurrentPasteboard(
            changeCount: currentChangeCount,
            showMessage: showMessage,
            skipOwnWrites: true
        )
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

        lastWrittenPasteboardSignature = IOSClipSignature(clip)
        lastObservedPasteboardChangeCount = pasteboard.changeCount
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

    func clearUnpinned() {
        clips.removeAll { !$0.isPinned }
        persist()
        lastCopyMessage = "Cleared unpinned clips."
    }

    func clearAll() {
        clips.removeAll()
        persist()
        lastCopyMessage = "Cleared history."
    }

    func clearMessage() {
        lastCopyMessage = nil
    }

    func replaceAll(_ clips: [IOSClip]) {
        self.clips = Array(clips.prefix(maxClips))
        persist()
    }

    private func upsert(_ clip: IOSClip) {
        var savedClip = clip
        if let existing = clips.first(where: { $0.matchesPayload(of: clip) }) {
            savedClip.id = existing.id
            savedClip.isPinned = existing.isPinned
            savedClip.lastCopiedAt = existing.lastCopiedAt
        }
        clips.removeAll { $0.matchesPayload(of: clip) }
        clips.insert(savedClip, at: 0)
        if clips.count > maxClips {
            let pinned = clips.filter(\.isPinned)
            let unpinnedSlots = max(0, maxClips - pinned.count)
            clips = pinned + clips.filter { !$0.isPinned }.prefix(unpinnedSlots)
        }
        persist()
    }

    private func captureCurrentPasteboard(
        changeCount: Int? = nil,
        showMessage: Bool,
        skipOwnWrites: Bool
    ) -> IOSPasteboardCaptureResult {
        let observedChangeCount = changeCount ?? pasteboard.changeCount
        lastObservedPasteboardChangeCount = observedChangeCount
        guard let clip = currentPasteboardClip() else {
            if showMessage {
                lastCopyMessage = "Clipboard is empty."
            }
            return .empty
        }

        let signature = IOSClipSignature(clip)
        if skipOwnWrites, signature == lastWrittenPasteboardSignature {
            return .ownWrite
        }

        upsert(clip)
        if showMessage {
            lastCopyMessage = "Saved current \(clip.kind.toastName)."
        }
        return .saved(clip.kind)
    }

    private func currentPasteboardClip() -> IOSClip? {
        if let image = pasteboard.image,
           let data = image.pngData() {
            return IOSClip(
                kind: .image,
                title: "Clipboard image",
                detail: "\(Int(image.size.width)) x \(Int(image.size.height))",
                imageData: data
            )
        }

        if let url = pasteboard.url {
            let cleanedURL = IOSClipboardContentCleaner.removingTrackingParameters(from: url) ?? url
            return IOSClip(
                kind: .link,
                title: cleanedURL.host(percentEncoded: false) ?? cleanedURL.absoluteString,
                detail: cleanedURL.absoluteString,
                content: cleanedURL.absoluteString
            )
        }

        if let text = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                let cleanedURL = IOSClipboardContentCleaner.removingTrackingParameters(from: url) ?? url
                return IOSClip(
                    kind: .link,
                    title: cleanedURL.host(percentEncoded: false) ?? cleanedURL.absoluteString.previewLine(limit: 64),
                    detail: cleanedURL.absoluteString,
                    content: cleanedURL.absoluteString
                )
            }

            return IOSClip(
                kind: .text,
                title: text.previewLine(limit: 72),
                detail: text.previewLine(limit: 140),
                content: text
            )
        }

        return nil
    }

    private func persist() {
        guard let data = try? encoder.encode(clips) else {
            return
        }
        defaults.set(data, forKey: clipsKey)
    }
}

enum IOSPasteboardCaptureResult: Equatable {
    case saved(IOSClipKind)
    case unchanged
    case ownWrite
    case empty

    var didSave: Bool {
        if case .saved = self {
            return true
        }
        return false
    }
}

private struct IOSClipSignature: Equatable {
    let kind: IOSClipKind
    let content: String?
    let imageData: Data?

    init(_ clip: IOSClip) {
        self.kind = clip.kind
        self.content = clip.content
        self.imageData = clip.imageData
    }
}

private struct IOSClipSearchQuery {
    var terms: [String] = []
    var kind: IOSClipKind?
    var pinned: Bool?

    init(_ rawValue: String) {
        for token in rawValue.split(whereSeparator: \.isWhitespace).map(String.init) {
            let lowercased = token.lowercased()
            if let value = lowercased.value(afterPrefix: "kind:") ?? lowercased.value(afterPrefix: "type:") {
                kind = IOSClipKind(searchToken: value)
            } else if let value = lowercased.value(afterPrefix: "is:") {
                pinned = value == "pinned" ? true : value == "unpinned" ? false : pinned
            } else if lowercased == "pinned" {
                pinned = true
            } else {
                terms.append(token)
            }
        }
    }

    func matches(_ clip: IOSClip) -> Bool {
        if let kind, clip.kind != kind {
            return false
        }
        if let pinned, clip.isPinned != pinned {
            return false
        }
        return terms.allSatisfy { clip.searchText.localizedCaseInsensitiveContains($0) }
    }
}

private extension IOSClip {
    func matchesPayload(of other: IOSClip) -> Bool {
        kind == other.kind &&
        content == other.content &&
        imageData == other.imageData
    }
}

private extension IOSClipKind {
    var toastName: String {
        switch self {
        case .text: "text"
        case .link: "link"
        case .image: "image"
        }
    }

    init?(searchToken: String) {
        switch searchToken {
        case "text", "txt":
            self = .text
        case "link", "links", "url":
            self = .link
        case "image", "images", "photo":
            self = .image
        default:
            return nil
        }
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
    func value(afterPrefix prefix: String) -> String? {
        guard hasPrefix(prefix) else {
            return nil
        }
        return String(dropFirst(prefix.count))
    }

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

enum IOSClipboardContentCleaner {
    static func removingTrackingParameters(from url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty
        else {
            return url
        }
        let filtered = queryItems.filter { item in
            !trackingParameterNames.contains(item.name.lowercased())
        }
        guard filtered.count != queryItems.count else {
            return url
        }
        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.url
    }

    private static let trackingParameterNames: Set<String> = [
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content",
        "fbclid",
        "gclid",
        "gbraid",
        "wbraid",
        "msclkid",
        "mc_cid",
        "mc_eid",
        "igshid"
    ]
}
