import CryptoKit
import Foundation

enum EncryptedHistoryStoreError: Error {
    case corruptStoreIsolated(URL)
    case missingCombinedRepresentation
}

struct StoredClipboardSnapshot: Codable, Sendable {
    var items: [ClipboardItem]
}

actor EncryptedHistoryStore {
    private let fileURL: URL
    private let keyStore: KeychainKeyStore
    private let blobStore: EncryptedBlobStore

    init(fileURL: URL? = nil, keyStore: KeychainKeyStore = KeychainKeyStore()) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Clippa", isDirectory: true)
        let root = base ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Clippa", isDirectory: true)
        self.fileURL = fileURL ?? root.appendingPathComponent("history.aesgcm")
        self.keyStore = keyStore
        self.blobStore = EncryptedBlobStore(folderURL: root.appendingPathComponent("BinaryPayloads", isDirectory: true), keyStore: keyStore)
    }

    func load() async throws -> StoredClipboardSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return StoredClipboardSnapshot(items: [])
        }

        do {
            let combined = try Data(contentsOf: fileURL)
            let keyData = try await keyStore.loadOrCreateKey()
            let box = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(box, using: SymmetricKey(data: keyData))
            let diskSnapshot = try JSONDecoder.clippa.decode(DiskClipboardSnapshot.self, from: decrypted)
            let items = try await materialize(diskSnapshot.items)
            return StoredClipboardSnapshot(items: items)
        } catch {
            let isolated = fileURL.deletingLastPathComponent()
                .appendingPathComponent("history-corrupt-\(Int(Date().timeIntervalSince1970)).aesgcm")
            try? FileManager.default.moveItem(at: fileURL, to: isolated)
            throw EncryptedHistoryStoreError.corruptStoreIsolated(isolated)
        }
    }

    func save(_ snapshot: StoredClipboardSnapshot) async throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let diskSnapshot = try await diskSnapshot(from: snapshot)
        let encoded = try JSONEncoder.clippa.encode(diskSnapshot)
        let keyData = try await keyStore.loadOrCreateKey()
        let sealed = try AES.GCM.seal(encoded, using: SymmetricKey(data: keyData))
        guard let combined = sealed.combined else {
            throw EncryptedHistoryStoreError.missingCombinedRepresentation
        }
        try combined.write(to: fileURL, options: .atomic)
    }

    private func diskSnapshot(from snapshot: StoredClipboardSnapshot) async throws -> DiskClipboardSnapshot {
        var diskItems: [DiskClipboardItem] = []
        var activeBlobFilenames: Set<String> = []
        for item in snapshot.items {
            let diskPayload: DiskClipboardPayload
            switch item.payload {
            case .text(let value):
                diskPayload = .text(value)
            case .url(let url):
                diskPayload = .url(url)
            case .files(let refs):
                diskPayload = .files(refs)
            case .image(let data, let uti):
                let filename = "image-\(item.payloadHash).blob"
                _ = try await blobStore.save(data, filename: filename)
                activeBlobFilenames.insert(filename)
                diskPayload = .imageBlob(filename: filename, uti: uti)
            }
            diskItems.append(DiskClipboardItem(item: item, payload: diskPayload))
        }
        try await blobStore.removeAll(except: activeBlobFilenames)
        return DiskClipboardSnapshot(items: diskItems)
    }

    private func materialize(_ diskItems: [DiskClipboardItem]) async throws -> [ClipboardItem] {
        var items: [ClipboardItem] = []
        for diskItem in diskItems {
            let payload: ClipboardPayload
            switch diskItem.payload {
            case .text(let value):
                payload = .text(value)
            case .url(let url):
                payload = .url(url)
            case .files(let refs):
                payload = .files(refs)
            case .imageBlob(let filename, let uti):
                let data = try await blobStore.load(filename: filename) ?? Data()
                payload = .image(data: data, uti: uti)
            }
            items.append(ClipboardItem(
                id: diskItem.id,
                kind: diskItem.kind,
                createdAt: diskItem.createdAt,
                lastUsedAt: diskItem.lastUsedAt,
                preview: diskItem.preview,
                payload: payload,
                payloadHash: diskItem.payloadHash,
                isPinned: diskItem.isPinned,
                sourceBundleIdentifier: diskItem.sourceBundleIdentifier
            ))
        }
        return items
    }
}

private struct DiskClipboardSnapshot: Codable, Sendable {
    var items: [DiskClipboardItem]
}

private struct DiskClipboardItem: Codable, Sendable {
    var id: UUID
    var kind: ClipboardItemKind
    var createdAt: Date
    var lastUsedAt: Date
    var preview: String
    var payload: DiskClipboardPayload
    var payloadHash: String
    var isPinned: Bool
    var sourceBundleIdentifier: String?

    init(item: ClipboardItem, payload: DiskClipboardPayload) {
        self.id = item.id
        self.kind = item.kind
        self.createdAt = item.createdAt
        self.lastUsedAt = item.lastUsedAt
        self.preview = item.preview
        self.payload = payload
        self.payloadHash = item.payloadHash
        self.isPinned = item.isPinned
        self.sourceBundleIdentifier = item.sourceBundleIdentifier
    }
}

private enum DiskClipboardPayload: Codable, Sendable {
    case text(String)
    case url(URL)
    case imageBlob(filename: String, uti: String?)
    case files([FileReference])
}

extension JSONEncoder {
    static var clippa: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var clippa: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
