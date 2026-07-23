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

extension IOSClip {
    static let sampleClips: [IOSClip] = [
        IOSClip(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            kind: .text,
            title: "Shipping address",
            detail: "123 Market Street, San Francisco",
            content: "123 Market Street, San Francisco",
            createdAt: Date(timeIntervalSince1970: 3),
            isPinned: true
        ),
        IOSClip(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            kind: .link,
            title: "github.com",
            detail: "https://github.com/Vaniawl/Clippa",
            content: "https://github.com/Vaniawl/Clippa",
            createdAt: Date(timeIntervalSince1970: 2)
        ),
        IOSClip(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            kind: .text,
            title: "Invoice note",
            detail: "Thanks, I will send the invoice today.",
            content: "Thanks, I will send the invoice today.",
            createdAt: Date(timeIntervalSince1970: 1)
        )
    ]
}
