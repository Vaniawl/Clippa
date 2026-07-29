import CryptoKit
import Foundation

enum EncryptedHistoryStoreError: Error {
    case corruptStoreIsolated(URL)
    case missingCombinedRepresentation
    case missingBlob(String)
    case payloadIsNotAnImage
}

struct StoredClipboardSnapshot: Codable, Sendable {
    var items: [ClipboardItem]
}

actor EncryptedHistoryStore {
    private let fileURL: URL
    private let keyStore: LocalHistoryKeyStore
    private let blobStore: EncryptedBlobStore
    private var recoveredMissingBlobCount = 0
    private var latestSaveGeneration = 0

    init(
        fileURL: URL? = nil,
        keyStore: LocalHistoryKeyStore = LocalHistoryKeyStore(),
        blobFolderURL: URL? = nil
    ) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Clippa", isDirectory: true)
        let root = base ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Clippa", isDirectory: true)
        self.fileURL = fileURL ?? root.appendingPathComponent("history.aesgcm")
        self.keyStore = keyStore
        self.blobStore = EncryptedBlobStore(
            folderURL: blobFolderURL ?? root.appendingPathComponent("BinaryPayloads", isDirectory: true),
            keyStore: keyStore
        )
    }

    func load() async throws -> StoredClipboardSnapshot {
        recoveredMissingBlobCount = 0
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return StoredClipboardSnapshot(items: [])
        }

        let combined = try Data(contentsOf: fileURL)
        let keyData = try await keyStore.loadOrCreateKey()
        do {
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

    func recoveryMessage() -> String? {
        guard recoveredMissingBlobCount > 0 else {
            return nil
        }
        return String(
            localized: "\(recoveredMissingBlobCount) image clip(s) were skipped because their encrypted files were missing."
        )
    }

    func save(_ snapshot: StoredClipboardSnapshot) async throws {
        try await save(snapshot, generation: nil)
    }

    func save(_ snapshot: StoredClipboardSnapshot, generation: Int) async throws {
        try await save(snapshot, generation: Optional(generation))
    }

    private func save(_ snapshot: StoredClipboardSnapshot, generation: Int?) async throws {
        if let generation {
            guard generation >= latestSaveGeneration else {
                return
            }
            latestSaveGeneration = generation
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let (diskSnapshot, activeBlobFilenames) = try await diskSnapshot(from: snapshot)
        let encoded = try JSONEncoder.clippa.encode(diskSnapshot)
        let keyData = try await keyStore.loadOrCreateKey()
        let sealed = try AES.GCM.seal(encoded, using: SymmetricKey(data: keyData))
        guard let combined = sealed.combined else {
            throw EncryptedHistoryStoreError.missingCombinedRepresentation
        }
        if let generation, generation < latestSaveGeneration {
            return
        }
        try combined.write(to: fileURL, options: .atomic)
        try? await blobStore.removeAll(except: activeBlobFilenames)
    }

    func resolvePayload(_ payload: ClipboardPayload) async throws -> ClipboardPayload {
        guard case .storedImage(let filename, let uti, _, _) = payload else {
            return payload
        }
        guard let data = try await blobStore.load(filename: filename) else {
            throw EncryptedHistoryStoreError.missingBlob(filename)
        }
        return .image(data: data, uti: uti)
    }

    func loadImageData(for payload: ClipboardPayload) async throws -> Data {
        switch try await resolvePayload(payload) {
        case .image(let data, _):
            return data
        default:
            throw EncryptedHistoryStoreError.payloadIsNotAnImage
        }
    }

    private func diskSnapshot(
        from snapshot: StoredClipboardSnapshot
    ) async throws -> (DiskClipboardSnapshot, Set<String>) {
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
                if try await !blobStore.contains(filename: filename) {
                    _ = try await blobStore.save(data, filename: filename)
                }
                activeBlobFilenames.insert(filename)
                diskPayload = .imageBlob(filename: filename, uti: uti, metadata: item.imageMetadata)
            case .storedImage(let filename, let uti, let metadata, _):
                guard try await blobStore.contains(filename: filename) else {
                    throw EncryptedHistoryStoreError.missingBlob(filename)
                }
                activeBlobFilenames.insert(filename)
                diskPayload = .imageBlob(filename: filename, uti: uti, metadata: metadata)
            }
            diskItems.append(DiskClipboardItem(item: item, payload: diskPayload))
        }
        return (DiskClipboardSnapshot(items: diskItems), activeBlobFilenames)
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
            case .imageBlob(let filename, let uti, let metadata):
                guard try await blobStore.contains(filename: filename) else {
                    recoveredMissingBlobCount += 1
                    continue
                }
                let resolvedMetadata = metadata ?? ClipboardImageMetadata(
                    widthPixels: nil,
                    heightPixels: nil,
                    byteCount: 0,
                    uti: uti
                )
                payload = .storedImage(
                    filename: filename,
                    uti: uti,
                    metadata: resolvedMetadata,
                    payloadHash: diskItem.payloadHash
                )
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
                sourceBundleIdentifier: diskItem.sourceBundleIdentifier,
                imageMetadata: payload.imageMetadata
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
    case imageBlob(filename: String, uti: String?, metadata: ClipboardImageMetadata?)
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
