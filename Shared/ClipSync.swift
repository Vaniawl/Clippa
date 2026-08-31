import CloudKit
import CryptoKit
import Foundation
#if os(macOS)
import Security
#endif

enum SyncedClipKind: String, Codable, Sendable {
    case text
    case link
    case image
}

struct SyncedClip: Codable, Equatable, Sendable {
    var recordName: String
    var fingerprint: String
    var kind: SyncedClipKind?
    var content: String?
    var imageData: Data?
    var createdAt: Date
    var lastUsedAt: Date
    var isPinned: Bool
    var modifiedAt: Date
    var originDeviceID: String
    var isDeleted: Bool

    static let maximumPayloadBytes = 20 * 1_024 * 1_024

    var isEligibleForCloud: Bool {
        if let imageData {
            return imageData.count <= Self.maximumPayloadBytes
        }
        if let content {
            return content.utf8.count <= Self.maximumPayloadBytes
        }
        return isDeleted
    }

    static func fingerprint(kind: SyncedClipKind, content: String? = nil, imageData: Data? = nil) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(kind.rawValue.utf8))
        hasher.update(data: Data([0]))
        if let content {
            hasher.update(data: Data(content.utf8))
        }
        if let imageData {
            hasher.update(data: imageData)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func tombstone(at date: Date, originDeviceID: String) -> SyncedClip {
        SyncedClip(
            recordName: recordName,
            fingerprint: fingerprint,
            kind: nil,
            content: nil,
            imageData: nil,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            isPinned: false,
            modifiedAt: date,
            originDeviceID: originDeviceID,
            isDeleted: true
        )
    }
}

struct ClipSyncMetadata: Codable, Sendable {
    var modifiedAtByRecordName: [String: Date]
    var tombstones: [SyncedClip]
    var originDeviceID: String

    init(
        modifiedAtByRecordName: [String: Date] = [:],
        tombstones: [SyncedClip] = [],
        originDeviceID: String = UUID().uuidString
    ) {
        self.modifiedAtByRecordName = modifiedAtByRecordName
        self.tombstones = tombstones
        self.originDeviceID = originDeviceID
    }
}

enum ClipSyncState: Equatable, Sendable {
    case idle
    case syncing
    case synced(Date)
    case unavailable(String)
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            "Waiting to sync"
        case .syncing:
            "Syncing with iCloud…"
        case .synced:
            "Synced with iCloud"
        case .unavailable(let message), .failed(let message):
            message
        }
    }

    var symbolName: String {
        switch self {
        case .idle:
            "icloud"
        case .syncing:
            "arrow.triangle.2.circlepath.icloud"
        case .synced:
            "checkmark.icloud.fill"
        case .unavailable:
            "icloud.slash"
        case .failed:
            "exclamationmark.icloud"
        }
    }

    var isSyncing: Bool {
        self == .syncing
    }
}

enum CloudAccountAvailability: Equatable, Sendable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case unknown
}

enum ClipSyncError: LocalizedError, Sendable {
    case accountUnavailable(CloudAccountAvailability)

    var errorDescription: String? {
        switch self {
        case .accountUnavailable(.noAccount):
            "Sign in to iCloud to sync clips."
        case .accountUnavailable(.restricted):
            "iCloud access is restricted on this device."
        case .accountUnavailable(.temporarilyUnavailable):
            "iCloud is temporarily unavailable."
        case .accountUnavailable(.unknown), .accountUnavailable(.available):
            "iCloud sync is unavailable."
        }
    }
}

protocol ClipSyncRepository: Sendable {
    func accountAvailability() async throws -> CloudAccountAvailability
    func prepareForRemoteChangeNotifications() async throws
    func fetchAll() async throws -> [SyncedClip]
    func save(_ records: [SyncedClip]) async throws
    func delete(recordNames: [String]) async throws
}

extension ClipSyncRepository {
    func prepareForRemoteChangeNotifications() async throws {}
}

actor ClipSyncService {
    private let repository: any ClipSyncRepository

    init(repository: any ClipSyncRepository) {
        self.repository = repository
    }

    func prepareForRemoteChangeNotifications() async throws {
        let availability = try await repository.accountAvailability()
        guard availability == .available else {
            throw ClipSyncError.accountUnavailable(availability)
        }
        try await repository.prepareForRemoteChangeNotifications()
    }

    func synchronize(localRecords: [SyncedClip]) async throws -> [SyncedClip] {
        let availability = try await repository.accountAvailability()
        guard availability == .available else {
            throw ClipSyncError.accountUnavailable(availability)
        }

        for attempt in 0..<2 {
            let remoteRecords = try await repository.fetchAll()
            let plan = ClipSyncMerger.makePlan(local: localRecords, remote: remoteRecords)
            do {
                try await repository.save(plan.recordsToSave)
                try await repository.delete(recordNames: plan.recordNamesToDelete)
                return plan.mergedRecords
            } catch let error as CKError where error.code == .serverRecordChanged && attempt == 0 {
                continue
            }
        }

        throw CKError(.serverRecordChanged)
    }
}

enum ClipSyncServiceFactory {
    static func makeCloudKitService() -> ClipSyncService? {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              hasCloudKitContainerEntitlement(currentICloudContainerIdentifiers()) else {
            return nil
        }
        return ClipSyncService(repository: CloudKitClipSyncRepository())
    }

    static func hasCloudKitContainerEntitlement(_ identifiers: [String]?) -> Bool {
        identifiers?.contains(CloudKitClipSyncRepository.containerIdentifier) == true
    }

    private static func currentICloudContainerIdentifiers() -> [String]? {
#if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else {
            return nil
        }
        return SecTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.icloud-container-identifiers" as CFString,
            nil
        ) as? [String]
#else
        [CloudKitClipSyncRepository.containerIdentifier]
#endif
    }
}

struct ClipSyncPlan: Equatable, Sendable {
    var mergedRecords: [SyncedClip]
    var recordsToSave: [SyncedClip]
    var recordNamesToDelete: [String]
}

enum ClipSyncMerger {
    static func makePlan(local: [SyncedClip], remote: [SyncedClip]) -> ClipSyncPlan {
        let allRecords = local + remote
        let grouped = Dictionary(grouping: allRecords, by: \.fingerprint)
        var mergedRecords: [SyncedClip] = []
        var recordsToSave: [SyncedClip] = []
        var recordNamesToDelete: [String] = []

        for records in grouped.values {
            guard var winner = records.max(by: isOlder) else {
                continue
            }
            let canonicalName = records.map(\.recordName).min() ?? winner.recordName
            winner.recordName = canonicalName
            mergedRecords.append(winner)

            let canonicalRemote = remote.first { $0.recordName == canonicalName }
            if canonicalRemote != winner {
                recordsToSave.append(winner)
            }

            recordNamesToDelete.append(contentsOf: remote.lazy
                .filter { $0.fingerprint == winner.fingerprint && $0.recordName != canonicalName }
                .map(\.recordName))
        }

        return ClipSyncPlan(
            mergedRecords: mergedRecords.sorted { $0.modifiedAt > $1.modifiedAt },
            recordsToSave: recordsToSave,
            recordNamesToDelete: Array(Set(recordNamesToDelete)).sorted()
        )
    }

    private static func isOlder(_ left: SyncedClip, _ right: SyncedClip) -> Bool {
        if left.modifiedAt != right.modifiedAt {
            return left.modifiedAt < right.modifiedAt
        }
        if left.isDeleted != right.isDeleted {
            return !left.isDeleted && right.isDeleted
        }
        if left.originDeviceID != right.originDeviceID {
            return left.originDeviceID < right.originDeviceID
        }
        return left.recordName < right.recordName
    }
}

actor CloudKitClipSyncRepository: ClipSyncRepository {
    static let containerIdentifier = "iCloud.app.clippa.Clippa"
    static let subscriptionIdentifier = "clippa-private-database-changes-v1"

    private let container: CKContainer
    private let database: CKDatabase

    init(container: CKContainer = CKContainer(identifier: CloudKitClipSyncRepository.containerIdentifier)) {
        self.container = container
        self.database = container.privateCloudDatabase
    }

    func accountAvailability() async throws -> CloudAccountAvailability {
        switch try await container.accountStatus() {
        case .available:
            .available
        case .noAccount:
            .noAccount
        case .restricted:
            .restricted
        case .temporarilyUnavailable:
            .temporarilyUnavailable
        case .couldNotDetermine:
            .unknown
        @unknown default:
            .unknown
        }
    }

    func prepareForRemoteChangeNotifications() async throws {
        do {
            _ = try await database.subscription(for: Self.subscriptionIdentifier)
            return
        } catch let error as CKError where error.code == .unknownItem {
            // The subscription is installed once per iCloud account below.
        }

        let subscription = CKDatabaseSubscription(subscriptionID: Self.subscriptionIdentifier)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        _ = try await database.save(subscription)
    }

    func fetchAll() async throws -> [SyncedClip] {
        let query = CKQuery(recordType: Fields.recordType, predicate: NSPredicate(value: true))
        var result: [SyncedClip] = []
        let firstPage: (matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?)
        do {
            firstPage = try await database.records(matching: query, resultsLimit: CKQueryOperation.maximumResults)
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
        var page = firstPage
        result.append(contentsOf: try decode(page.matchResults))

        while let cursor = page.queryCursor {
            page = try await database.records(continuingMatchFrom: cursor, resultsLimit: CKQueryOperation.maximumResults)
            result.append(contentsOf: try decode(page.matchResults))
        }
        return result
    }

    func save(_ records: [SyncedClip]) async throws {
        for syncedClip in records where syncedClip.isEligibleForCloud {
            let recordID = CKRecord.ID(recordName: syncedClip.recordName)
            let record: CKRecord
            do {
                record = try await database.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: Fields.recordType, recordID: recordID)
            }

            let temporaryAssetURL = try configure(record, from: syncedClip)
            defer {
                if let temporaryAssetURL {
                    try? FileManager.default.removeItem(at: temporaryAssetURL)
                }
            }

            _ = try await database.save(record)
        }
    }

    func delete(recordNames: [String]) async throws {
        for recordName in recordNames {
            do {
                _ = try await database.deleteRecord(withID: CKRecord.ID(recordName: recordName))
            } catch let error as CKError where error.code == .unknownItem {
                continue
            }
        }
    }

    private func decode(_ results: [(CKRecord.ID, Result<CKRecord, any Error>)]) throws -> [SyncedClip] {
        try results.compactMap { _, result in
            switch result {
            case .success(let record):
                return decode(record)
            case .failure(let error):
                throw error
            }
        }
    }

    private func decode(_ record: CKRecord) -> SyncedClip? {
        let values = record.encryptedValues
        guard let fingerprint = values[Fields.fingerprint] as? String,
              let modifiedAt = values[Fields.modifiedAt] as? Date,
              let originDeviceID = values[Fields.originDeviceID] as? String
        else {
            return nil
        }

        let isDeleted = (values[Fields.isDeleted] as? NSNumber)?.boolValue ?? false
        let kind = (values[Fields.kind] as? String).flatMap(SyncedClipKind.init(rawValue:))
        var content = values[Fields.content] as? String
        var imageData: Data?

        if let asset = record[Fields.payloadAsset] as? CKAsset,
           let fileURL = asset.fileURL,
           let data = try? Data(contentsOf: fileURL) {
            if kind == .image {
                imageData = data
            } else if content == nil {
                content = String(data: data, encoding: .utf8)
            }
        }

        if !isDeleted, kind == nil {
            return nil
        }

        return SyncedClip(
            recordName: record.recordID.recordName,
            fingerprint: fingerprint,
            kind: kind,
            content: content,
            imageData: imageData,
            createdAt: values[Fields.createdAt] as? Date ?? modifiedAt,
            lastUsedAt: values[Fields.lastUsedAt] as? Date ?? modifiedAt,
            isPinned: (values[Fields.isPinned] as? NSNumber)?.boolValue ?? false,
            modifiedAt: modifiedAt,
            originDeviceID: originDeviceID,
            isDeleted: isDeleted
        )
    }

    @discardableResult
    private func configure(_ record: CKRecord, from clip: SyncedClip) throws -> URL? {
        let values = record.encryptedValues
        values[Fields.fingerprint] = clip.fingerprint as NSString
        values[Fields.modifiedAt] = clip.modifiedAt as NSDate
        values[Fields.originDeviceID] = clip.originDeviceID as NSString
        values[Fields.isDeleted] = NSNumber(value: clip.isDeleted)
        values[Fields.createdAt] = clip.createdAt as NSDate
        values[Fields.lastUsedAt] = clip.lastUsedAt as NSDate
        values[Fields.isPinned] = NSNumber(value: clip.isPinned)

        if let kind = clip.kind {
            values[Fields.kind] = kind.rawValue as NSString
        } else {
            values[Fields.kind] = nil
        }

        values[Fields.content] = nil
        record[Fields.payloadAsset] = nil
        guard !clip.isDeleted else {
            return nil
        }

        let assetData: Data?
        if let imageData = clip.imageData {
            assetData = imageData
        } else if let content = clip.content, content.utf8.count > 64 * 1_024 {
            assetData = Data(content.utf8)
        } else {
            assetData = nil
            if let content = clip.content {
                values[Fields.content] = content as NSString
            }
        }

        guard let assetData else {
            return nil
        }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clippa-sync-\(UUID().uuidString)")
        try assetData.write(to: fileURL, options: .atomic)
        record[Fields.payloadAsset] = CKAsset(fileURL: fileURL)
        return fileURL
    }

    private enum Fields {
        static let recordType = "ClippaClip"
        static let fingerprint = "encryptedFingerprint"
        static let kind = "encryptedKind"
        static let content = "encryptedContent"
        static let createdAt = "encryptedCreatedAt"
        static let lastUsedAt = "encryptedLastUsedAt"
        static let isPinned = "encryptedIsPinned"
        static let modifiedAt = "encryptedModifiedAt"
        static let originDeviceID = "encryptedOriginDeviceID"
        static let isDeleted = "encryptedIsDeleted"
        static let payloadAsset = "payloadAsset"
    }
}
