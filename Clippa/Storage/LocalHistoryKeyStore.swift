import Foundation
import Security

enum LocalHistoryKeyStoreError: Error, Equatable {
    case unexpectedData
    case keyGenerationFailed
}

actor LocalHistoryKeyStore {
    private let fallbackURL: URL

    init(fallbackURL: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Clippa", isDirectory: true)
        let root = base ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Clippa", isDirectory: true)
        self.fallbackURL = fallbackURL ?? root.appendingPathComponent("history.key")
    }

    func loadOrCreateKey() throws -> Data {
        if let existing = try loadFallbackKey() {
            guard existing.count == 32 else {
                throw LocalHistoryKeyStoreError.unexpectedData
            }
            return existing
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw LocalHistoryKeyStoreError.keyGenerationFailed
        }
        let keyData = Data(bytes)
        try saveFallbackKey(keyData)
        return keyData
    }

    private func loadFallbackKey() throws -> Data? {
        guard FileManager.default.fileExists(atPath: fallbackURL.path) else {
            return nil
        }
        return try Data(contentsOf: fallbackURL)
    }

    private func saveFallbackKey(_ data: Data) throws {
        let folder = fallbackURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: fallbackURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fallbackURL.path)
    }
}
