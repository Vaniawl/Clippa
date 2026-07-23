import Foundation

enum IOSClipKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case link
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        }
    }
}

struct IOSClip: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: IOSClipKind
    var title: String
    var detail: String
    var content: String?
    var imageData: Data?
    var createdAt: Date
    var lastCopiedAt: Date?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        kind: IOSClipKind,
        title: String,
        detail: String,
        content: String? = nil,
        imageData: Data? = nil,
        createdAt: Date = Date(),
        lastCopiedAt: Date? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.content = content
        self.imageData = imageData
        self.createdAt = createdAt
        self.lastCopiedAt = lastCopiedAt
        self.isPinned = isPinned
    }

    var searchText: String {
        "\(title) \(detail) \(content ?? "")"
    }
}
