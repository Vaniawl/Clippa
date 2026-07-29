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
    private(set) var storageMessage: String?

    private let defaults: UserDefaults
    private let pasteboard: IOSPasteboard
    private let persistence: IOSClipPersistence
    private let clipsKey = "clippa.ios.clips"
    private let maxClips = 200
    private let maxImageByteCount = 25 * 1024 * 1024
    private var lastObservedPasteboardChangeCount: Int?
    private var lastWrittenPasteboardSignature: IOSClipSignature?

    init(
        defaults: UserDefaults = .standard,
        pasteboard: IOSPasteboard = UIPasteboard.general,
        storageDirectoryURL: URL? = nil
    ) {
        self.defaults = defaults
        self.pasteboard = pasteboard
        self.persistence = IOSClipPersistence(
            rootURL: storageDirectoryURL ?? Self.defaultStorageDirectory(for: defaults)
        )

        let loadResult = persistence.load(legacyArchive: defaults.data(forKey: clipsKey))
        self.clips = loadResult.clips
        self.storageMessage = loadResult.message
        self.lastCopyMessage = loadResult.message
        if loadResult.didMigrateLegacyArchive {
            defaults.removeObject(forKey: clipsKey)
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
        lastCopyMessage = String(localized: "Copied. Go back and paste.")
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
        lastCopyMessage = String(localized: "Cleared unpinned clips.")
    }

    func clearAll() {
        clips.removeAll()
        persist()
        lastCopyMessage = String(localized: "Cleared history.")
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
                lastCopyMessage = String(localized: "Clipboard is empty.")
            }
            return .empty
        }

        let signature = IOSClipSignature(clip)
        if skipOwnWrites, signature == lastWrittenPasteboardSignature {
            return .ownWrite
        }

        upsert(clip)
        if showMessage {
            lastCopyMessage = String(localized: "Saved current \(clip.kind.toastName).")
        }
        return .saved(clip.kind)
    }

    private func currentPasteboardClip() -> IOSClip? {
        if let image = pasteboard.image,
           let data = image.pngData() {
            guard data.count <= maxImageByteCount else {
                lastCopyMessage = String(localized: "That image is too large to save.")
                return nil
            }
            return IOSClip(
                kind: .image,
                title: String(localized: "Clipboard image"),
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
        let snapshot = clips
        persistence.scheduleSave(snapshot) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                switch result {
                case .success:
                    break
                case .failure:
                    self.storageMessage = String(localized: "Clippa could not save the latest history changes.")
                    self.lastCopyMessage = self.storageMessage
                }
            }
        }
    }

    func flushPersistence() async {
        await persistence.flush()
    }

    private static func defaultStorageDirectory(for defaults: UserDefaults) -> URL {
        if defaults === UserDefaults.standard {
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
            return base.appendingPathComponent("Clippa", isDirectory: true)
                .appendingPathComponent("iOSHistory", isDirectory: true)
        }
        let identifierKey = "clippa.ios.test-storage-identifier"
        let identifier: String
        if let existing = defaults.string(forKey: identifierKey) {
            identifier = existing
        } else {
            identifier = UUID().uuidString
            defaults.set(identifier, forKey: identifierKey)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("ClippaIOSTests-\(identifier)", isDirectory: true)
    }
}

private final class IOSClipPersistence: @unchecked Sendable {
    struct LoadResult {
        var clips: [IOSClip]
        var message: String?
        var didMigrateLegacyArchive: Bool
    }

    enum PersistenceError: Error, Sendable {
        case missingImageData(UUID)
    }

    private static let queue = DispatchQueue(label: "app.clippa.ios-history", qos: .utility)
    private let rootURL: URL
    private let manifestURL: URL
    private let imagesURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.manifestURL = rootURL.appendingPathComponent("clips.json")
        self.imagesURL = rootURL.appendingPathComponent("Images", isDirectory: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load(legacyArchive: Data?) -> LoadResult {
        Self.queue.sync {
            if FileManager.default.fileExists(atPath: manifestURL.path) {
                return loadManifest()
            }
            guard let legacyArchive else {
                return LoadResult(clips: [], message: nil, didMigrateLegacyArchive: false)
            }
            do {
                let clips = try JSONDecoder().decode([IOSClip].self, from: legacyArchive)
                try save(clips)
                return LoadResult(clips: clips, message: nil, didMigrateLegacyArchive: true)
            } catch {
                return LoadResult(
                    clips: [],
                    message: String(localized: "The previous iPhone history could not be migrated and was left untouched."),
                    didMigrateLegacyArchive: false
                )
            }
        }
    }

    func scheduleSave(
        _ clips: [IOSClip],
        completion: @escaping @Sendable (Result<Void, PersistenceError>) -> Void
    ) {
        Self.queue.async { [self] in
            do {
                try save(clips)
                completion(.success(()))
            } catch let error as PersistenceError {
                completion(.failure(error))
            } catch {
                completion(.failure(.missingImageData(UUID())))
            }
        }
    }

    func flush() async {
        await withCheckedContinuation { continuation in
            Self.queue.async {
                continuation.resume()
            }
        }
    }

    private func loadManifest() -> LoadResult {
        do {
            let data = try Data(contentsOf: manifestURL)
            let records = try decoder.decode([IOSClipDiskRecord].self, from: data)
            var missingImageCount = 0
            let clips = records.compactMap { record -> IOSClip? in
                if let imageFilename = record.imageFilename {
                    guard Self.isSafeFilename(imageFilename) else {
                        missingImageCount += 1
                        return nil
                    }
                    let imageURL = imagesURL.appendingPathComponent(imageFilename)
                    guard let imageData = try? Data(contentsOf: imageURL) else {
                        missingImageCount += 1
                        return nil
                    }
                    return record.materialize(imageData: imageData)
                }
                return record.materialize(imageData: nil)
            }
            let message = missingImageCount == 0
                ? nil
                : String(localized: "\(missingImageCount) image clip(s) were skipped because their files were missing.")
            return LoadResult(clips: clips, message: message, didMigrateLegacyArchive: false)
        } catch {
            let isolatedURL = rootURL.appendingPathComponent(
                "clips-corrupt-\(Int(Date().timeIntervalSince1970)).json"
            )
            try? FileManager.default.moveItem(at: manifestURL, to: isolatedURL)
            return LoadResult(
                clips: [],
                message: String(localized: "The iPhone history manifest was damaged and has been isolated."),
                didMigrateLegacyArchive: false
            )
        }
    }

    private func save(_ clips: [IOSClip]) throws {
        try FileManager.default.createDirectory(
            at: imagesURL,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )

        var activeImageFilenames: Set<String> = []
        let records = try clips.map { clip -> IOSClipDiskRecord in
            guard clip.kind == .image else {
                return IOSClipDiskRecord(clip: clip, imageFilename: nil)
            }
            guard let imageData = clip.imageData else {
                throw PersistenceError.missingImageData(clip.id)
            }
            let filename = "image-\(clip.id.uuidString).png"
            let imageURL = imagesURL.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: imageURL.path) {
                try imageData.write(to: imageURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
            activeImageFilenames.insert(filename)
            return IOSClipDiskRecord(clip: clip, imageFilename: filename)
        }

        let encoded = try encoder.encode(records)
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        try encoded.write(
            to: manifestURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )

        let existingImages = try FileManager.default.contentsOfDirectory(
            at: imagesURL,
            includingPropertiesForKeys: nil
        )
        for url in existingImages where !activeImageFilenames.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func isSafeFilename(_ filename: String) -> Bool {
        !filename.isEmpty &&
        filename == URL(fileURLWithPath: filename).lastPathComponent &&
        !filename.contains("/") &&
        !filename.contains("\\")
    }
}

private struct IOSClipDiskRecord: Codable, Sendable {
    var id: UUID
    var kind: IOSClipKind
    var title: String
    var detail: String
    var content: String?
    var imageFilename: String?
    var createdAt: Date
    var lastCopiedAt: Date?
    var isPinned: Bool

    init(clip: IOSClip, imageFilename: String?) {
        id = clip.id
        kind = clip.kind
        title = clip.title
        detail = clip.detail
        content = clip.content
        self.imageFilename = imageFilename
        createdAt = clip.createdAt
        lastCopiedAt = clip.lastCopiedAt
        isPinned = clip.isPinned
    }

    func materialize(imageData: Data?) -> IOSClip {
        IOSClip(
            id: id,
            kind: kind,
            title: title,
            detail: detail,
            content: content,
            imageData: imageData,
            createdAt: createdAt,
            lastCopiedAt: lastCopiedAt,
            isPinned: isPinned
        )
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
        case .text: String(localized: "text")
        case .link: String(localized: "link")
        case .image: String(localized: "image")
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
        case .all: String(localized: "All")
        case .pinned: String(localized: "Pinned")
        case .text: String(localized: "Text")
        case .link: String(localized: "Links")
        case .image: String(localized: "Images")
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
