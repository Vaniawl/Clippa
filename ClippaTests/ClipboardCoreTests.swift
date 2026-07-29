import AppKit
import Carbon.HIToolbox
import CryptoKit
import ImageIO
import SwiftUI
import XCTest
@testable import Clippa

@MainActor
final class ClipboardCoreTests: XCTestCase {
    func testCreatesSupportedItemKinds() {
        let file = FileReference(url: URL(fileURLWithPath: "/tmp/example.txt"))
        XCTAssertEqual(ClipboardItem(payload: .text("hello")).kind, .text)
        XCTAssertEqual(ClipboardItem(payload: .url(URL(string: "https://example.com")!)).kind, .url)
        XCTAssertEqual(ClipboardItem(payload: .image(data: Data([1, 2, 3]), uti: "public.tiff")).kind, .image)
        XCTAssertEqual(ClipboardItem(payload: .files([file])).kind, .files)
    }

    func testDeduplicatesAndMovesExistingItemToTop() {
        let store = ClipboardStore()
        let old = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        store.add(payload: .text("same"), sourceBundleIdentifier: "a", date: old)
        store.add(payload: .text("same"), sourceBundleIdentifier: "b", date: newer)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.createdAt, newer)
        XCTAssertEqual(store.items.first?.sourceBundleIdentifier, "b")
    }

    func testUsingOlderItemDoesNotChangeCopyOrder() {
        let store = ClipboardStore()
        store.add(payload: .text("old"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 10))
        store.add(payload: .text("new"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 20))

        let oldItem = store.items.first { $0.preview == "old" }!
        store.use(oldItem, date: Date(timeIntervalSince1970: 30))

        XCTAssertEqual(store.items.map(\.preview), ["new", "old"])
        XCTAssertEqual(
            store.items.first { $0.preview == "old" }?.lastUsedAt,
            Date(timeIntervalSince1970: 30)
        )
    }

    func testPinnedItemsAppearFirstInAllAndRemainVisibleInKindFilters() {
        let store = ClipboardStore()
        let now = Date()
        store.add(payload: .text("old"), sourceBundleIdentifier: nil, date: now.addingTimeInterval(-1))
        store.add(payload: .text("new"), sourceBundleIdentifier: nil, date: now)
        store.select(store.items.last!)
        store.togglePinSelected()

        XCTAssertEqual(store.items.first?.preview, "new")
        XCTAssertEqual(store.filteredItems(query: "", filter: .all).map(\.preview), ["old", "new"])
        XCTAssertEqual(store.filteredItems(query: "", filter: .text).map(\.preview), ["new", "old"])
        XCTAssertEqual(store.filteredItems(query: "", filter: .pinned).map(\.preview), ["old"])
    }

    func testItemScopedPinAndDeleteActionsSelectTargetItem() {
        let store = ClipboardStore()
        let now = Date()
        store.add(payload: .text("first"), sourceBundleIdentifier: nil, date: now.addingTimeInterval(-1))
        store.add(payload: .text("second"), sourceBundleIdentifier: nil, date: now)
        let first = store.items.first { $0.preview == "first" }!
        let second = store.items.first { $0.preview == "second" }!

        store.select(second)
        store.togglePin(first)
        XCTAssertEqual(store.selectedItemID, first.id)
        XCTAssertTrue(store.items.first { $0.id == first.id }?.isPinned == true)

        store.delete(second)
        XCTAssertNil(store.items.first { $0.id == second.id })
        XCTAssertEqual(store.selectedItemID, first.id)

        store.selectedFilter = .pinned
        XCTAssertEqual(store.selectedItemID, first.id)
    }

    func testDeletedItemsCanBeRestored() {
        let store = ClipboardStore()
        let now = Date()
        store.add(payload: .text("first"), sourceBundleIdentifier: nil, date: now.addingTimeInterval(-1))
        store.add(payload: .text("second"), sourceBundleIdentifier: nil, date: now)
        let first = store.items.first { $0.preview == "first" }!

        let deleted = store.delete(first)
        XCTAssertNil(store.items.first { $0.preview == "first" })

        store.restore(deleted.map { [$0] } ?? [])
        XCTAssertEqual(store.items.count, 2)
        XCTAssertNotNil(store.items.first { $0.preview == "first" })
    }

    func testClearedUnpinnedItemsCanBeRestored() {
        let store = ClipboardStore()
        let now = Date()
        store.add(payload: .text("pinned"), sourceBundleIdentifier: nil, date: now.addingTimeInterval(-1))
        store.add(payload: .text("unpinned"), sourceBundleIdentifier: nil, date: now)
        store.togglePin(store.items.first { $0.preview == "pinned" }!)

        let removed = store.clearUnpinned()
        XCTAssertEqual(store.items.map(\.preview), ["pinned"])

        store.restore(removed)
        XCTAssertEqual(Set(store.items.map(\.preview)), Set(["pinned", "unpinned"]))
    }

    func testLimitsUnpinnedHistoryTo100() {
        let store = ClipboardStore()
        for index in 0..<120 {
            store.add(payload: .text("item \(index)"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: TimeInterval(index)))
        }
        XCTAssertEqual(store.items.filter { !$0.isPinned }.count, 100)
        XCTAssertEqual(store.items.first?.preview, "item 119")
    }

    func testConfigurableHistoryLimitIsApplied() {
        let store = ClipboardStore(
            policy: ClipboardHistoryPolicy(retention: .forever, limit: .fifty)
        )
        for index in 0..<75 {
            store.add(
                payload: .text("item \(index)"),
                sourceBundleIdentifier: nil,
                date: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        XCTAssertEqual(store.items.count, 50)
        XCTAssertEqual(store.items.first?.preview, "item 74")
    }

    func testForeverRetentionKeepsOldUnpinnedItems() {
        let store = ClipboardStore(
            policy: ClipboardHistoryPolicy(retention: .forever, limit: .oneHundred)
        )
        store.add(payload: .text("old"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 0))
        store.applyOrderingAndRetention(now: Date(timeIntervalSince1970: 365 * 24 * 60 * 60))

        XCTAssertEqual(store.items.map(\.preview), ["old"])
    }

    func testRetentionKeepsPinnedAndRemovesOldUnpinned() {
        let store = ClipboardStore()
        let old = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 8 * 24 * 60 * 60)
        store.add(payload: .text("unpinned old"), sourceBundleIdentifier: nil, date: old)
        store.add(payload: .text("pinned old"), sourceBundleIdentifier: nil, date: old)
        store.select(store.items.first { $0.preview == "pinned old" }!)
        store.togglePinSelected()
        store.applyOrderingAndRetention(now: now)
        XCTAssertEqual(store.items.map(\.preview), ["pinned old"])
    }

    func testRetentionKeepsRecentlyUsedOldUnpinned() {
        let store = ClipboardStore()
        let old = Date(timeIntervalSince1970: 0)
        let recent = Date(timeIntervalSince1970: 8 * 24 * 60 * 60)
        store.add(payload: .text("old but used"), sourceBundleIdentifier: nil, date: old)

        let item = store.items.first!
        store.use(item, date: recent)

        XCTAssertEqual(store.items.first?.preview, "old but used")
        XCTAssertEqual(store.items.first?.lastUsedAt, recent)
    }

    func testSearchAndFilters() {
        let store = ClipboardStore()
        store.add(payload: .text("alpha note"), sourceBundleIdentifier: nil)
        store.add(payload: .url(URL(string: "https://example.com/beta")!), sourceBundleIdentifier: nil)
        store.add(payload: .image(data: Data([1]), uti: nil), sourceBundleIdentifier: nil)
        store.add(payload: .files([FileReference(url: URL(fileURLWithPath: "/tmp/report.pdf"))]), sourceBundleIdentifier: nil)
        store.togglePin(store.items.first { $0.preview == "alpha note" }!)
        XCTAssertEqual(store.filteredItems(query: "beta", filter: .all).count, 1)
        XCTAssertEqual(store.filteredItems(query: "", filter: .image).first?.kind, .image)
        XCTAssertEqual(store.filteredItems(query: "", filter: .url).first?.kind, .url)
        XCTAssertEqual(store.filteredItems(query: "", filter: .files).first?.kind, .files)
        XCTAssertEqual(store.filteredItems(query: "", filter: .pinned).first?.preview, "alpha note")
        XCTAssertEqual(store.filteredItems(query: "alpha", filter: .all).first?.preview, "alpha note")
        XCTAssertEqual(store.filteredItems(query: "alpha", filter: .text).first?.preview, "alpha note")
    }

    func testAdvancedSearchTokens() {
        let store = ClipboardStore()
        let now = Date()
        store.add(payload: .text("alpha note"), sourceBundleIdentifier: "com.apple.Notes", date: now)
        store.add(payload: .url(URL(string: "https://example.com/beta")!), sourceBundleIdentifier: "com.apple.Safari", date: now)
        store.add(payload: .image(data: Data([1]), uti: nil), sourceBundleIdentifier: "com.apple.Preview", date: now.addingTimeInterval(-86_400))
        store.togglePin(store.items.first { $0.kind == .text }!)

        XCTAssertEqual(store.filteredItems(query: "kind:link beta", filter: .all).first?.kind, .url)
        XCTAssertEqual(store.filteredItems(query: "from:safari", filter: .all).first?.kind, .url)
        XCTAssertEqual(store.filteredItems(query: "is:pinned alpha", filter: .all).first?.kind, .text)
        XCTAssertTrue(store.filteredItems(query: "today kind:image", filter: .all).isEmpty)
    }

    func testContentCleanerNormalizesTextAndRemovesTrackingParameters() {
        XCTAssertEqual(
            ClipboardContentCleaner.normalizedText("  one\r\ntwo\u{0000}  "),
            "one\ntwo"
        )

        let dirtyURL = URL(string: "https://example.com/read?utm_source=newsletter&id=42&fbclid=abc")!
        XCTAssertEqual(
            ClipboardContentCleaner.removingTrackingParameters(from: dirtyURL)?.absoluteString,
            "https://example.com/read?id=42"
        )

        let cleanedPayload = ClipboardPayload.text("https://example.com/?gclid=1&q=clippa")
            .cleaned(normalizeText: true, removeTrackingParameters: true)
        XCTAssertEqual(cleanedPayload, .url(URL(string: "https://example.com/?q=clippa")!))
    }

    func testPinnedExportImportRoundTrip() throws {
        let source = ClipboardStore()
        source.add(payload: .text("pinned"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1))
        source.add(payload: .text("regular"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 2))
        source.togglePin(source.items.first { $0.preview == "pinned" }!)

        let data = try source.exportPinnedData()
        let target = ClipboardStore()
        let imported = try target.importPinnedData(data, date: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(target.items.first?.preview, "pinned")
        XCTAssertTrue(target.items.first?.isPinned == true)
        XCTAssertTrue(try target.importPinnedData(data).isEmpty)
    }

    func testDerivedVisibleStateUpdatesOnlyWhenVisibleItemsChange() {
        let store = ClipboardStore()
        let initialRevision = store.visibleItemsRevision

        store.add(payload: .text("alpha"), sourceBundleIdentifier: nil)
        XCTAssertEqual(store.pinnedItemCount, 0)
        XCTAssertGreaterThan(store.visibleItemsRevision, initialRevision)

        let revisionAfterAdd = store.visibleItemsRevision
        store.searchQuery = "missing"
        XCTAssertTrue(store.visibleItems.isEmpty)
        XCTAssertGreaterThan(store.visibleItemsRevision, revisionAfterAdd)

        let revisionAfterEmptySearch = store.visibleItemsRevision
        store.searchQuery = "still missing"
        XCTAssertEqual(store.visibleItemsRevision, revisionAfterEmptySearch)

        store.searchQuery = ""
        let revisionBeforePin = store.visibleItemsRevision
        store.togglePin(store.items.first!)
        XCTAssertEqual(store.pinnedItemCount, 1)
        XCTAssertEqual(store.visibleItems.map(\.preview), ["alpha"])
        XCTAssertEqual(store.visibleItemsRevision, revisionBeforePin)
    }

    func testImageMetadataUsesImagePropertiesWithoutViewDecode() throws {
        let data = try makePNGData(width: 2, height: 3)
        let item = ClipboardItem(payload: .image(data: data, uti: "public.png"))

        XCTAssertEqual(item.imageMetadata?.widthPixels, 2)
        XCTAssertEqual(item.imageMetadata?.heightPixels, 3)
        XCTAssertEqual(item.imageMetadata?.byteCount, data.count)
        XCTAssertEqual(item.imageMetadata?.uti, "public.png")
    }

    func testImageThumbnailIsDownsampledForPanelRendering() async throws {
        let data = try makePNGData(width: 800, height: 400)
        let loadedImage = await ClipboardImageCache.image(for: UUID().uuidString, data: data)
        let image = try XCTUnwrap(loadedImage)

        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 256)
    }

    func testPanelScreenshotFixtureRendersAtReferenceSize() throws {
        let store = ClipboardStore(persistenceEnabled: false)
        store.add(payload: .text("Screenshot fixture"), sourceBundleIdentifier: "com.apple.Notes")
        store.add(
            payload: .url(URL(string: "https://clippa.app/reference")!),
            sourceBundleIdentifier: "com.apple.Safari"
        )
        if let link = store.items.first(where: { $0.kind == .url }) {
            store.togglePin(link)
        }
        store.showUndoMessage(String(localized: "Clip deleted"))
        let view = PanelView(
            store: store,
            pasteDestination: PanelPasteDestination(
                applicationName: "Notes",
                bundleIdentifier: "com.apple.Notes"
            ),
            onPasteSelected: {},
            onPasteAsPlainText: { _ in },
            onCopy: { _ in },
            onPreview: { _ in },
            onOpen: { _ in },
            onExtractText: { _ in },
            onTogglePin: { _ in },
            onDelete: { _ in },
            onUndo: {}
        )
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: DesignSystem.panelWidth, height: DesignSystem.panelHeight)
        )
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))

        XCTAssertEqual(hostingView.bounds.width, DesignSystem.panelWidth)
        XCTAssertEqual(hostingView.bounds.height, DesignSystem.panelHeight)
        XCTAssertEqual(
            bitmap.pixelsWide * Int(DesignSystem.panelHeight),
            bitmap.pixelsHigh * Int(DesignSystem.panelWidth)
        )
        XCTAssertGreaterThan(pngData.count, 10_000)
        let attachment = XCTAttachment(data: pngData, uniformTypeIdentifier: "public.png")
        attachment.name = "Clippa Panel Reference"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPrivacyMarkersAndExcludedBundleIDs() {
        let filter = PrivacyFilter(excludedBundleIdentifiers: ["secret.app"])
        XCTAssertFalse(filter.shouldCapture(types: [.init("org.nspasteboard.ConcealedType")], sourceBundleIdentifier: nil))
        XCTAssertFalse(filter.shouldCapture(types: [.string], sourceBundleIdentifier: "secret.app"))
        XCTAssertTrue(filter.shouldCapture(types: [.string], sourceBundleIdentifier: "notes.app"))
    }

    func testFileReferenceReportsMissingFile() {
        let ref = FileReference(url: URL(fileURLWithPath: "/tmp/clippa-definitely-missing"))
        XCTAssertFalse(ref.exists)
    }

    func testAESGCMRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let payload = Data("private".utf8)
        let box = try AES.GCM.seal(payload, using: key)
        let combined = try XCTUnwrap(box.combined)
        let opened = try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: key)
        XCTAssertEqual(opened, payload)
    }

    func testKeyStoreMigratesExistingLocalKeyAfterKeychainVerification() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClippaTests.\(UUID().uuidString)", isDirectory: true)
        let keyURL = folder.appendingPathComponent("history.key")
        let backupURL = folder.appendingPathComponent("history.key.legacy-backup")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let key = Data(repeating: 7, count: 32)
        try key.write(to: keyURL)
        let keychain = TestHistoryKeychain()

        let store = LocalHistoryKeyStore(
            fallbackURL: keyURL,
            legacyBackupURL: backupURL,
            keychain: keychain
        )
        let loaded = try await store.loadOrCreateKey()

        XCTAssertEqual(loaded, key)
        XCTAssertEqual(try keychain.load(), key)
        XCTAssertFalse(FileManager.default.fileExists(atPath: keyURL.path))
        XCTAssertEqual(try Data(contentsOf: backupURL), key)
        try? FileManager.default.removeItem(at: folder)
    }

    func testKeyStoreCreatesAndVerifiesKeychainKeyWithoutLocalKeyFile() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClippaTests.\(UUID().uuidString)", isDirectory: true)
        let keyURL = folder.appendingPathComponent("history.key")
        let keychain = TestHistoryKeychain()

        let store = LocalHistoryKeyStore(fallbackURL: keyURL, keychain: keychain)
        let key = try await store.loadOrCreateKey()

        XCTAssertEqual(key.count, 32)
        XCTAssertEqual(try keychain.load(), key)
        XCTAssertFalse(FileManager.default.fileExists(atPath: keyURL.path))
        try? FileManager.default.removeItem(at: folder)
    }

    func testKeyStoreKeepsLegacyKeyWhenKeychainVerificationFails() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClippaTests.\(UUID().uuidString)", isDirectory: true)
        let keyURL = folder.appendingPathComponent("history.key")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let key = Data(repeating: 9, count: 32)
        try key.write(to: keyURL)
        let keychain = TestHistoryKeychain(dropsWrites: true)
        let store = LocalHistoryKeyStore(fallbackURL: keyURL, keychain: keychain)

        do {
            _ = try await store.loadOrCreateKey()
            XCTFail("Expected Keychain verification to fail.")
        } catch {
            XCTAssertEqual(error as? LocalHistoryKeyStoreError, .keychainVerificationFailed)
        }
        XCTAssertEqual(try Data(contentsOf: keyURL), key)
        try? FileManager.default.removeItem(at: folder)
    }

    func testEncryptedHistoryLoadsImageLazilyAndDoesNotRewriteUnchangedBlob() async throws {
        let fixture = try HistoryStoreFixture()
        let data = try makePNGData(width: 4, height: 3)
        let item = ClipboardItem(payload: .image(data: data, uti: "public.png"))

        try await fixture.store.save(StoredClipboardSnapshot(items: [item]))
        let blobURL = try XCTUnwrap(
            try FileManager.default.contentsOfDirectory(
                at: fixture.blobFolderURL,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ).first
        )
        let initialDate = try blobURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        let loaded = try await fixture.store.load()
        guard case .storedImage = try XCTUnwrap(loaded.items.first).payload else {
            return XCTFail("Expected image bytes to remain on disk until requested.")
        }
        let resolvedData = try await fixture.store.loadImageData(for: loaded.items[0].payload)
        XCTAssertEqual(resolvedData, data)

        try await Task.sleep(for: .milliseconds(20))
        try await fixture.store.save(loaded)
        let finalDate = try blobURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        XCTAssertEqual(finalDate, initialDate)
        fixture.remove()
    }

    func testMissingImageBlobSkipsOnlyAffectedHistoryItem() async throws {
        let fixture = try HistoryStoreFixture()
        let image = ClipboardItem(payload: .image(data: Data([1, 2, 3]), uti: "public.data"))
        let text = ClipboardItem(payload: .text("still available"))
        try await fixture.store.save(StoredClipboardSnapshot(items: [image, text]))

        for url in try FileManager.default.contentsOfDirectory(
            at: fixture.blobFolderURL,
            includingPropertiesForKeys: nil
        ) {
            try FileManager.default.removeItem(at: url)
        }

        let loaded = try await fixture.store.load()
        XCTAssertEqual(loaded.items.map(\.preview), ["still available"])
        let recoveryMessage = await fixture.store.recoveryMessage()
        XCTAssertNotNil(recoveryMessage)
        fixture.remove()
    }

    func testFailedManifestCommitDoesNotCleanExistingBlobs() async throws {
        let fixture = try HistoryStoreFixture(manifestIsDirectory: true)
        try FileManager.default.createDirectory(at: fixture.blobFolderURL, withIntermediateDirectories: true)
        let orphanURL = fixture.blobFolderURL.appendingPathComponent("orphan.blob")
        try Data("recoverable".utf8).write(to: orphanURL)
        let snapshot = StoredClipboardSnapshot(items: [
            ClipboardItem(payload: .image(data: Data([4, 5, 6]), uti: nil))
        ])

        do {
            try await fixture.store.save(snapshot)
            XCTFail("Expected writing a manifest over a directory to fail.")
        } catch {
            XCTAssertTrue(FileManager.default.fileExists(atPath: orphanURL.path))
        }
        fixture.remove()
    }

    func testOlderSaveGenerationCannotOverwriteNewerSnapshot() async throws {
        let fixture = try HistoryStoreFixture()
        let newer = StoredClipboardSnapshot(items: [ClipboardItem(payload: .text("newer"))])
        let older = StoredClipboardSnapshot(items: [ClipboardItem(payload: .text("older"))])

        try await fixture.store.save(newer, generation: 2)
        try await fixture.store.save(older, generation: 1)

        let loadedPreviews = try await fixture.store.load().items.map(\.preview)
        XCTAssertEqual(loadedPreviews, ["newer"])
        fixture.remove()
    }

    func testPinnedImportRebuildsUntrustedDerivedMetadata() throws {
        let store = ClipboardStore(persistenceEnabled: false)
        let forged = ClipboardItem(
            id: UUID(),
            kind: .image,
            createdAt: .distantPast,
            lastUsedAt: .distantPast,
            preview: "forged preview",
            payload: .text("trusted payload"),
            payloadHash: "forged hash",
            isPinned: false,
            sourceBundleIdentifier: "example.source"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let archive = TestPinnedClipboardArchive(items: [forged])

        _ = try store.importPinnedData(encoder.encode(archive))

        let imported = try XCTUnwrap(store.items.first)
        XCTAssertEqual(imported.kind, .text)
        XCTAssertEqual(imported.preview, "trusted payload")
        XCTAssertEqual(imported.payloadHash, ClipboardPayload.text("trusted payload").stableHash)
        XCTAssertTrue(imported.isPinned)
    }

    func testWrongKeyFailsAESGCMOpen() throws {
        let payload = Data("private".utf8)
        let box = try AES.GCM.seal(payload, using: SymmetricKey(size: .bits256))
        let combined = try XCTUnwrap(box.combined)
        XCTAssertThrowsError(try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: SymmetricKey(size: .bits256)))
    }

    func testShowPanelShortcutDefaultsAndPersists() throws {
        let suiteName = "ClippaTests.shortcuts.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        var settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.showPanelShortcut.displayString, "⇧⌘V")

        settings.showPanelShortcut = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(controlKey | optionKey))

        settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.showPanelShortcut.displayString, "⌃⌥B")

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testHistorySettingsPersist() throws {
        let suiteName = "ClippaTests.historySettings.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        var settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.historyPolicy, .default)

        settings.historyRetention = .oneMonth
        settings.historyLimit = .fiveHundred
        settings.historyDiskBudget = .oneGigabyte

        settings = AppSettings(defaults: defaults)
        XCTAssertEqual(
            settings.historyPolicy,
            ClipboardHistoryPolicy(
                retention: .oneMonth,
                limit: .fiveHundred,
                diskBudget: .oneGigabyte
            )
        )

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDiskBudgetEvictsOldestUnpinnedPayloadsButKeepsPinnedItems() {
        let store = ClipboardStore(
            policy: ClipboardHistoryPolicy(
                retention: .forever,
                limit: .fiveHundred,
                diskBudget: .oneHundredMegabytes
            ),
            persistenceEnabled: false
        )
        let largeMetadata = ClipboardImageMetadata(
            widthPixels: 8_000,
            heightPixels: 8_000,
            byteCount: 60_000_000,
            uti: "public.png"
        )
        let oldLargeImage = ClipboardItem(
            payload: .storedImage(
                filename: "old.blob",
                uti: "public.png",
                metadata: largeMetadata,
                payloadHash: "old"
            ),
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let pinnedLargeImage = ClipboardItem(
            payload: .storedImage(
                filename: "pinned.blob",
                uti: "public.png",
                metadata: largeMetadata,
                payloadHash: "pinned"
            ),
            createdAt: Date(timeIntervalSince1970: 2),
            isPinned: true
        )

        store.restore([oldLargeImage, pinnedLargeImage])

        XCTAssertTrue(store.items.contains { $0.id == pinnedLargeImage.id })
        XCTAssertFalse(store.items.contains { $0.id == oldLargeImage.id })
    }

    func testSpaceAfterPasteSettingDefaultsOnAndPersists() throws {
        let suiteName = "ClippaTests.spaceAfterPaste.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        var settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.addSpaceAfterPaste)

        settings.addSpaceAfterPaste = false
        settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.addSpaceAfterPaste)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testPrivacyAndCleanupSettingsPersist() throws {
        let suiteName = "ClippaTests.privacyCleanup.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        var settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.normalizeCopiedText)
        XCTAssertTrue(settings.removeTrackingParametersFromLinks)
        XCTAssertFalse(settings.isCapturePaused)

        settings.normalizeCopiedText = true
        settings.removeTrackingParametersFromLinks = false
        settings.pauseCapture(for: 60)

        settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.normalizeCopiedText)
        XCTAssertFalse(settings.removeTrackingParametersFromLinks)
        XCTAssertTrue(settings.isCapturePaused)

        settings.resumeCapture()
        XCTAssertFalse(AppSettings(defaults: defaults).isCapturePaused)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testTrailingSpaceOnlyAppliesToTextAndLinksWhenEnabled() {
        XCTAssertTrue(PasteService.shouldAddTrailingSpace(to: .text("hello"), enabled: true))
        XCTAssertTrue(
            PasteService.shouldAddTrailingSpace(
                to: .url(URL(string: "https://example.com")!),
                enabled: true
            )
        )
        XCTAssertFalse(
            PasteService.shouldAddTrailingSpace(
                to: .image(data: Data([1]), uti: nil),
                enabled: true
            )
        )
        XCTAssertFalse(
            PasteService.shouldAddTrailingSpace(
                to: .files([FileReference(url: URL(fileURLWithPath: "/tmp/example.txt"))]),
                enabled: true
            )
        )
        XCTAssertFalse(PasteService.shouldAddTrailingSpace(to: .text("hello"), enabled: false))
    }

    @MainActor
    func testFilterSelectionWrapsWithHorizontalNavigation() {
        let store = ClipboardStore()

        XCTAssertEqual(store.selectedFilter, .all)
        store.selectAdjacentFilter(offset: -1)
        XCTAssertEqual(store.selectedFilter, .files)
        store.selectAdjacentFilter(offset: 1)
        XCTAssertEqual(store.selectedFilter, .all)
        store.selectAdjacentFilter(offset: 1)
        XCTAssertEqual(store.selectedFilter, .pinned)
    }

    func testCommandPMapsToTogglePin() throws {
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "p",
                charactersIgnoringModifiers: "p",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_P)
            )
        )

        XCTAssertEqual(PanelController.action(for: event), .togglePin)
    }

    func testCommandReturnMapsToPasteAsPlainText() throws {
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                keyCode: UInt16(kVK_Return)
            )
        )

        XCTAssertEqual(PanelController.action(for: event), .pastePlainText)
    }

    func testPanelPositionStaysInsideVisibleFrameAtEdges() {
        let screen = TestScreen(frame: NSRect(x: 0, y: 0, width: 800, height: 600), visibleFrame: NSRect(x: 0, y: 25, width: 800, height: 550))
        let size = NSSize(width: 500, height: 292)
        let points = [
            NSPoint(x: 2, y: 2),
            NSPoint(x: 798, y: 2),
            NSPoint(x: 2, y: 598),
            NSPoint(x: 798, y: 598)
        ]
        for point in points {
            let frame = PanelController.panelFrame(near: point, size: size, screens: [screen])
            XCTAssertTrue(screen.visibleFrame.contains(frame.origin))
            XCTAssertLessThanOrEqual(frame.maxX, screen.visibleFrame.maxX)
            XCTAssertGreaterThanOrEqual(frame.minY, screen.visibleFrame.minY)
        }
    }

    func testMultiDisplayUsesDisplayContainingCursor() {
        let left = TestScreen(frame: NSRect(x: -800, y: 0, width: 800, height: 600), visibleFrame: NSRect(x: -800, y: 0, width: 800, height: 560))
        let right = TestScreen(frame: NSRect(x: 0, y: 0, width: 800, height: 600), visibleFrame: NSRect(x: 0, y: 0, width: 800, height: 560))
        let frame = PanelController.panelFrame(near: NSPoint(x: -700, y: 400), size: NSSize(width: 300, height: 200), screens: [left, right])
        XCTAssertLessThan(frame.maxX, 0)
    }
}

private func makePNGData(width: Int, height: Int) throws -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw XCTSkip("Could not create test bitmap context.")
    }
    context.setFillColor(NSColor.systemBlue.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else {
        throw XCTSkip("Could not create test image.")
    }

    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
        throw XCTSkip("Could not create PNG destination.")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw XCTSkip("Could not finalize PNG data.")
    }
    return data as Data
}

private final class TestHistoryKeychain: HistoryKeychain, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private let dropsWrites: Bool

    init(data: Data? = nil, dropsWrites: Bool = false) {
        self.data = data
        self.dropsWrites = dropsWrites
    }

    func load() throws -> Data? {
        lock.withLock { data }
    }

    func save(_ data: Data) throws {
        guard !dropsWrites else {
            return
        }
        lock.withLock {
            self.data = data
        }
    }
}

private struct HistoryStoreFixture {
    let rootURL: URL
    let blobFolderURL: URL
    let store: EncryptedHistoryStore

    init(manifestIsDirectory: Bool = false) throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClippaHistoryTests.\(UUID().uuidString)", isDirectory: true)
        blobFolderURL = rootURL.appendingPathComponent("BinaryPayloads", isDirectory: true)
        let manifestURL = rootURL.appendingPathComponent("history.aesgcm")
        let keyURL = rootURL.appendingPathComponent("history.key")
        let keyStore = LocalHistoryKeyStore(
            fallbackURL: keyURL,
            keychain: TestHistoryKeychain()
        )
        store = EncryptedHistoryStore(
            fileURL: manifestURL,
            keyStore: keyStore,
            blobFolderURL: blobFolderURL
        )
        if manifestIsDirectory {
            try FileManager.default.createDirectory(at: manifestURL, withIntermediateDirectories: true)
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private struct TestPinnedClipboardArchive: Codable {
    var version = 1
    var exportedAt = Date()
    var items: [ClipboardItem]
}

private final class TestScreen: NSScreen {
    private let testFrame: NSRect
    private let testVisibleFrame: NSRect

    init(frame: NSRect, visibleFrame: NSRect) {
        self.testFrame = frame
        self.testVisibleFrame = visibleFrame
        super.init()
    }

    override var frame: NSRect { testFrame }
    override var visibleFrame: NSRect { testVisibleFrame }
}
