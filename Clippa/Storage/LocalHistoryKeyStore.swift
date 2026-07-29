import Foundation
import Security

enum LocalHistoryKeyStoreError: Error, Equatable {
    case unexpectedData
    case keyGenerationFailed
    case keychain(OSStatus)
    case keychainVerificationFailed
}

protocol HistoryKeychain: Sendable {
    func load() throws -> Data?
    func save(_ data: Data) throws
}

final class SystemHistoryKeychain: HistoryKeychain, @unchecked Sendable {
    private let service: String
    private let account: String

    init(
        service: String = "app.clippa.Clippa.history",
        account: String = "history-encryption-key"
    ) {
        self.service = service
        self.account = account
    }

    func load() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw LocalHistoryKeyStoreError.unexpectedData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw LocalHistoryKeyStoreError.keychain(status)
        }
    }

    func save(_ data: Data) throws {
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw LocalHistoryKeyStoreError.keychain(updateStatus)
        }

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw LocalHistoryKeyStoreError.keychain(addStatus)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true
        ]
    }
}

actor LocalHistoryKeyStore {
    private let fallbackURL: URL
    private let legacyBackupURL: URL
    private let keychain: any HistoryKeychain

    init(
        fallbackURL: URL? = nil,
        legacyBackupURL: URL? = nil,
        keychain: any HistoryKeychain = SystemHistoryKeychain()
    ) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Clippa", isDirectory: true)
        let root = base ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Clippa", isDirectory: true)
        self.fallbackURL = fallbackURL ?? root.appendingPathComponent("history.key")
        self.legacyBackupURL = legacyBackupURL ?? root.appendingPathComponent("history.key.legacy-backup")
        self.keychain = keychain
    }

    func loadOrCreateKey() throws -> Data {
        if let existing = try keychain.load() {
            return try validated(existing)
        }

        if let legacy = try loadLegacyKey() {
            let key = try validated(legacy)
            try saveAndVerifyInKeychain(key)
            try preserveLegacyBackup()
            return key
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw LocalHistoryKeyStoreError.keyGenerationFailed
        }
        let keyData = Data(bytes)
        try saveAndVerifyInKeychain(keyData)
        return keyData
    }

    private func validated(_ data: Data) throws -> Data {
        guard data.count == 32 else {
            throw LocalHistoryKeyStoreError.unexpectedData
        }
        return data
    }

    private func loadLegacyKey() throws -> Data? {
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            return try Data(contentsOf: fallbackURL)
        }
        if FileManager.default.fileExists(atPath: legacyBackupURL.path) {
            return try Data(contentsOf: legacyBackupURL)
        }
        return nil
    }

    private func saveAndVerifyInKeychain(_ data: Data) throws {
        try keychain.save(data)
        guard try keychain.load() == data else {
            throw LocalHistoryKeyStoreError.keychainVerificationFailed
        }
    }

    private func preserveLegacyBackup() throws {
        guard FileManager.default.fileExists(atPath: fallbackURL.path),
              !FileManager.default.fileExists(atPath: legacyBackupURL.path)
        else {
            return
        }
        try FileManager.default.moveItem(at: fallbackURL, to: legacyBackupURL)
    }
}
