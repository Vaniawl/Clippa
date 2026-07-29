import CryptoKit
import Foundation

actor EncryptedBlobStore {
    private let folderURL: URL
    private let keyStore: LocalHistoryKeyStore

    init(folderURL: URL, keyStore: LocalHistoryKeyStore) {
        self.folderURL = folderURL
        self.keyStore = keyStore
    }

    func save(_ data: Data, id: UUID = UUID()) async throws -> String {
        try await save(data, filename: "\(id.uuidString).blob")
    }

    func save(_ data: Data, filename: String) async throws -> String {
        let url = try url(for: filename)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let keyData = try await keyStore.loadOrCreateKey()
        let sealed = try AES.GCM.seal(data, using: SymmetricKey(data: keyData))
        guard let combined = sealed.combined else {
            throw EncryptedBlobStoreError.missingCombinedRepresentation
        }
        try combined.write(to: url, options: .atomic)
        return filename
    }

    func load(filename: String) async throws -> Data? {
        let url = try url(for: filename)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let keyData = try await keyStore.loadOrCreateKey()
        let combined = try Data(contentsOf: url)
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: SymmetricKey(data: keyData))
    }

    func contains(filename: String) throws -> Bool {
        FileManager.default.fileExists(atPath: try url(for: filename).path)
    }

    func removeAll(except filenamesToKeep: Set<String>) throws {
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            return
        }
        let files = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
        for file in files where !filenamesToKeep.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func url(for filename: String) throws -> URL {
        guard !filename.isEmpty,
              filename == URL(fileURLWithPath: filename).lastPathComponent,
              !filename.contains("/"),
              !filename.contains("\\")
        else {
            throw EncryptedBlobStoreError.invalidFilename
        }
        return folderURL.appendingPathComponent(filename, isDirectory: false)
    }
}

enum EncryptedBlobStoreError: Error {
    case missingCombinedRepresentation
    case invalidFilename
}
