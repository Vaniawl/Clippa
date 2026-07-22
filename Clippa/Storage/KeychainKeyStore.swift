import Foundation
import Security

enum KeychainKeyStoreError: Error, Equatable {
    case unexpectedData
    case keyGenerationFailed
    case keychain(OSStatus)
}

actor KeychainKeyStore {
    private let service = "dev.local.Clippa.history"
    private let account = "AES-GCM"

    func loadOrCreateKey() throws -> Data {
        if let existing = try loadKey() {
            guard existing.count == 32 else {
                throw KeychainKeyStoreError.unexpectedData
            }
            return existing
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw KeychainKeyStoreError.keyGenerationFailed
        }
        let keyData = Data(bytes)
        try saveKey(keyData)
        return keyData
    }

    private func loadKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
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

    private func saveKey(_ data: Data) throws {
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
}
