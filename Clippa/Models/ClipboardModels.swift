import Foundation
import CryptoKit

enum ClipboardItemKind: String, Codable, CaseIterable, Sendable {
    case text
    case url
    case image
    case files

    var displayName: String {
        switch self {
        case .text: String(localized: "Text")
        case .url: String(localized: "URL")
        case .image: String(localized: "Image")
        case .files: String(localized: "Files")
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .url: "link"
        case .image: "photo"
        case .files: "doc.on.doc"
        }
    }
}

enum ClipboardFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case pinned
    case text
    case url
    case image
    case files

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: String(localized: "All")
        case .pinned: String(localized: "Pinned")
        case .text: String(localized: "Text")
        case .url: String(localized: "Links")
        case .image: String(localized: "Images")
        case .files: String(localized: "Files")
        }
    }

    var symbolName: String {
        switch self {
        case .all: "tray.full"
        case .pinned: "pin"
        case .text: "text.alignleft"
        case .url: "link"
        case .image: "photo"
        case .files: "doc.on.doc"
        }
    }
}

struct FileReference: Codable, Hashable, Sendable {
    var path: String
    var bookmarkData: Data?

    init(url: URL, bookmarkData: Data? = nil) {
        self.path = url.path
        self.bookmarkData = bookmarkData
    }

    var url: URL { URL(fileURLWithPath: path) }
    var exists: Bool { FileManager.default.fileExists(atPath: path) }
    var displayName: String { url.lastPathComponent.isEmpty ? path : url.lastPathComponent }
}

enum ClipboardPayload: Codable, Equatable, Sendable {
    case text(String)
    case url(URL)
    case image(data: Data, uti: String?)
    case files([FileReference])

    var kind: ClipboardItemKind {
        switch self {
        case .text: .text
        case .url: .url
        case .image: .image
        case .files: .files
        }
    }

    var preview: String {
        switch self {
        case .text(let value):
            value.previewLine
        case .url(let url):
            url.absoluteString
        case .image(let data, _):
            ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
        case .files(let refs):
            refs.map(\.displayName).joined(separator: ", ")
        }
    }

    var searchText: String {
        switch self {
        case .text(let value):
            value
        case .url(let url):
            url.absoluteString
        case .image:
            ClipboardItemKind.image.displayName
        case .files(let refs):
            refs.map { "\($0.displayName) \($0.path)" }.joined(separator: " ")
        }
    }

    var stableHash: String {
        var hasher = SHA256()
        hasher.update(data: Data(kind.rawValue.utf8))
        switch self {
        case .text(let value):
            hasher.update(data: Data(value.utf8))
        case .url(let url):
            hasher.update(data: Data(url.absoluteString.utf8))
        case .image(let data, let uti):
            hasher.update(data: Data((uti ?? "").utf8))
            hasher.update(data: data)
        case .files(let refs):
            for path in refs.map(\.path).sorted() {
                hasher.update(data: Data(path.utf8))
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: ClipboardItemKind
    var createdAt: Date
    var lastUsedAt: Date
    var preview: String
    var payload: ClipboardPayload
    var payloadHash: String
    var isPinned: Bool
    var sourceBundleIdentifier: String?

    init(
        id: UUID,
        kind: ClipboardItemKind,
        createdAt: Date,
        lastUsedAt: Date,
        preview: String,
        payload: ClipboardPayload,
        payloadHash: String,
        isPinned: Bool,
        sourceBundleIdentifier: String?
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.preview = preview
        self.payload = payload
        self.payloadHash = payloadHash
        self.isPinned = isPinned
        self.sourceBundleIdentifier = sourceBundleIdentifier
    }

    init(
        id: UUID = UUID(),
        payload: ClipboardPayload,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        isPinned: Bool = false,
        sourceBundleIdentifier: String? = nil
    ) {
        self.id = id
        self.kind = payload.kind
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt ?? createdAt
        self.preview = payload.preview
        self.payload = payload
        self.payloadHash = payload.stableHash
        self.isPinned = isPinned
        self.sourceBundleIdentifier = sourceBundleIdentifier
    }
}

extension String {
    var previewLine: String {
        let collapsed = split(whereSeparator: \.isNewline).joined(separator: " ")
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 160 {
            return trimmed
        }
        let end = trimmed.index(trimmed.startIndex, offsetBy: 160)
        return String(trimmed[..<end])
    }
}
