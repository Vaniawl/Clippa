import Foundation
import LocalAuthentication
import Security

enum KeychainKeyStoreError: Error, Equatable {
    case unexpectedData
    case keyGenerationFailed
    case keychain(OSStatus)
}

actor KeychainKeyStore {
    private let primaryService = "com.ivandovhosheia.Clippa.history.v2"
    private let legacyServices = ["dev.local.Clippa.history"]
    private let account = "AES-GCM"
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
                throw KeychainKeyStoreError.unexpectedData
            }
            return existing
        }

        for service in [primaryService] + legacyServices {
            if let existing = try loadKey(service: service) {
                guard existing.count == 32 else {
                    throw KeychainKeyStoreError.unexpectedData
                }
                try? saveFallbackKey(existing)
                if service != primaryService {
                    try? saveKey(existing, service: primaryService)
                }
                return existing
            }
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw KeychainKeyStoreError.keyGenerationFailed
        }
        let keyData = Data(bytes)
        try? saveKey(keyData, service: primaryService)
        try saveFallbackKey(keyData)
        return keyData
    }

    private func loadKey(service: String) throws -> Data? {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound || status == errSecInteractionNotAllowed || status == errSecAuthFailed {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainKeyStoreError.keychain(status)
        }
        guard let data = item as? Data else {
            throw KeychainKeyStoreError.unexpectedData
        }
        return data
    }

    private func saveKey(_ data: Data, service: String) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw KeychainKeyStoreError.keychain(status)
        }
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
