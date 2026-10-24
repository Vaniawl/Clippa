import AppKit
import Carbon.HIToolbox
import CryptoKit
import ImageIO
import XCTest
@testable import Clippa

@MainActor
final class ClipboardCoreTests: XCTestCase {
    func testTemplateValidationEditAndCaptureKeepSeparateIdentity() throws {
        let store = makeStore()
        XCTAssertThrowsError(try store.saveTemplate(title: " ", folder: "", body: "text"))
        XCTAssertThrowsError(try store.saveTemplate(title: "Name", folder: "", body: " "))
        let template = try store.saveTemplate(title: " Reply ", folder: " Work ", body: "Hello {name}")
        XCTAssertEqual(template.template, TextTemplate(title: "Reply", folder: "Work"))
        XCTAssertTrue(template.isPinned)
        store.add(payload: .text("Hello {name}"), sourceBundleIdentifier: "com.apple.Notes")
        XCTAssertEqual(store.items.count, 2)
        let updated = try store.saveTemplate(id: template.id, title: "Updated", folder: "Personal", body: "Hi {name}")
        XCTAssertEqual(updated.id, template.id)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.templateFolders, ["Personal"])
        XCTAssertEqual(store.filteredItems(query: "Personal Updated", filter: .templates).count, 1)
        store.togglePin(updated)
        XCTAssertTrue(store.items.first { $0.id == updated.id }!.isPinned)
        let removed = try XCTUnwrap(store.delete(updated))
        store.restore([removed])
        XCTAssertTrue(store.items.contains { $0.id == template.id && $0.isTemplate })
        XCTAssertThrowsError(try store.saveTemplate(id: UUID(), title: "Missing", folder: "", body: "Text"))
    }

    func testTemplateFoldersAndQuickPasteUseVisibleOrder() throws {
        let store = makeStore()
        let first = try store.saveTemplate(title: "A", folder: "Work", body: "First")
        let second = try store.saveTemplate(title: "B", folder: "Home", body: "Second")
        store.selectedTemplateFolder = "Work"
        XCTAssertEqual(store.quickPasteItem(at: 0)?.id, first.id)
        XCTAssertNil(store.quickPasteItem(at: 1))
        XCTAssertNil(store.quickPasteItem(at: -1))
        XCTAssertNil(store.quickPasteItem(at: 9))
        store.selectedTemplateFolder = nil
        XCTAssertEqual(store.quickPasteItem(at: 0)?.id, second.id)
        store.searchQuery = "First"
        XCTAssertEqual(store.quickPasteItem(at: 0)?.id, first.id)
    }

    func testTemplatePlaceholdersAreUniqueUnicodeAndNonRecursive() {
        let body = "Hi {ім’я}, {name}, {ім’я}! {date} {дата} {time} {час}. {\"json\":true}"
        XCTAssertEqual(TemplateRenderer.variables(in: body), ["ім’я", "name"])
        let rendered = TemplateRenderer.render(body, values: ["ім’я": "Оля", "name": "{date}"],
            date: Date(timeIntervalSince1970: 0), locale: Locale(identifier: "en_US"), timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertTrue(rendered.hasPrefix("Hi Оля, {date}, Оля! Jan 1, 1970 Jan 1, 1970"))
        XCTAssertTrue(rendered.hasSuffix("{\"json\":true}"))
        XCTAssertEqual(TemplateRenderer.render("{missing}"), "{missing}")
        XCTAssertEqual(TemplateRenderer.variables(in: "{a-b} { spaced name } {x\ny}"), ["a-b"])
    }

    func testTemplateExportImportKeepsMetadataAndDistinctBodies() throws {
        let source = makeStore()
        _ = try source.saveTemplate(title: "Reply", folder: "Work", body: "same")
        _ = try source.saveTemplate(title: "Greeting", folder: "Home", body: "same")
        source.add(payload: .text("same"), sourceBundleIdentifier: nil)
        source.togglePin(source.items.first { !$0.isTemplate }!)
        let data = try source.exportPinnedData()
        let target = makeStore()
        XCTAssertEqual(try target.importPinnedData(data).count, 3)
        XCTAssertEqual(target.items.filter(\.isTemplate).count, 2)
        XCTAssertEqual(target.templateFolders, ["Home", "Work"])
        XCTAssertTrue(try target.importPinnedData(data).isEmpty)
    }

    func testEncryptedTemplateAndUsageOrderingSurviveReload() async throws {
        let history = isolatedHistory()
        let store = ClipboardStore(historyStore: history)
        let now = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let template = try store.saveTemplate(title: "Private reply", folder: "Work", body: "secret {name}", date: now)
        store.add(payload: .text("newer"), sourceBundleIdentifier: nil, date: now.addingTimeInterval(0.1))
        store.use(template, date: now.addingTimeInterval(0.2))
        await store.flushPendingSave()
        let restored = ClipboardStore(historyStore: history)
        await restored.load()
        XCTAssertEqual(restored.items.first?.id, template.id)
        XCTAssertEqual(restored.items.first?.template, template.template)
        XCTAssertEqual(restored.items.first?.payload, .text("secret {name}"))
        XCTAssertNil(restored.storageMessage)
    }

    func testLatestSnapshotWinsAfterBurstOfWritesAndFlush() async throws {
        let history = isolatedHistory()
        let store = ClipboardStore(historyStore: history)
        for index in 0..<30 { store.add(payload: .text("Burst \(index)"), sourceBundleIdentifier: nil) }
        let last = try XCTUnwrap(store.items.first)
        let first = try XCTUnwrap(store.items.first { $0.preview == "Burst 0" })
        store.use(first)
        await store.flushPendingSave()
        let restored = ClipboardStore(historyStore: history)
        await restored.load()
        XCTAssertEqual(restored.items.count, 30)
        XCTAssertEqual(restored.items.first?.id, first.id)
        XCTAssertTrue(restored.items.contains { $0.id == last.id })
    }

    func testSaveFailureKeepsHistoryAndShowsRecoveryMessage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ClippaTests.failure.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocker = root.appendingPathComponent("not-a-directory")
        try Data([1]).write(to: blocker)
        let history = EncryptedHistoryStore(fileURL: blocker.appendingPathComponent("history.aesgcm"),
            keyStore: LocalHistoryKeyStore(fallbackURL: root.appendingPathComponent("history.key")))
        let store = ClipboardStore(historyStore: history)
        store.add(payload: .text("Keep this"), sourceBundleIdentifier: nil)
        await store.flushPendingSave()
        XCTAssertEqual(store.items.first?.preview, "Keep this")
        XCTAssertNotNil(store.storageMessage)
    }

    func testLegacyHistoryLoadsWithoutTemplateMetadata() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ClippaTests.legacy.\(UUID().uuidString)")
        let historyURL = root.appendingPathComponent("history.aesgcm")
        let keyStore = LocalHistoryKeyStore(fallbackURL: root.appendingPathComponent("history.key"))
        let key = try await keyStore.loadOrCreateKey()
        let legacy = ClipboardItem(payload: .text("legacy text"))
        let legacyEncoder = JSONEncoder()
        legacyEncoder.dateEncodingStrategy = .iso8601
        let data = try legacyEncoder.encode(StoredClipboardSnapshot(items: [legacy]))
        let sealed = try AES.GCM.seal(data, using: SymmetricKey(data: key))
        try XCTUnwrap(sealed.combined).write(to: historyURL)
        let history = EncryptedHistoryStore(fileURL: historyURL, keyStore: keyStore)
        let loaded = try await history.load()
        XCTAssertEqual(loaded.items.first?.payload, .text("legacy text"))
        XCTAssertNil(loaded.items.first?.template)
    }

    func testSearchEditingPreservesCaretAndNativeShortcuts() throws {
        for code in [kVK_LeftArrow, kVK_RightArrow] {
            XCTAssertNil(PanelController.action(for: try keyEvent(code), isEditingText: true))
            XCTAssertNil(PanelController.action(for: try keyEvent(code, flags: .option), isEditingText: true))
            XCTAssertNil(PanelController.action(for: try keyEvent(code, flags: .shift), isEditingText: true))
        }
        for code in [kVK_ANSI_C, kVK_ANSI_Z, kVK_Delete] {
            XCTAssertNil(PanelController.action(for: try keyEvent(code, flags: .command), isEditingText: true))
        }
        XCTAssertEqual(PanelController.action(for: try keyEvent(kVK_ANSI_RightBracket, flags: .command), isEditingText: true), .selectNextFilter)
        XCTAssertEqual(PanelController.action(for: try keyEvent(kVK_DownArrow), isEditingText: true), .selectNext)
    }

    func testFocusedPanelControlsKeepNativeActivation() throws {
        for code in [kVK_Return, kVK_DownArrow, kVK_UpArrow, kVK_LeftArrow, kVK_RightArrow] {
            XCTAssertNil(PanelController.action(for: try keyEvent(code), isSearchFocused: false))
        }
        XCTAssertEqual(PanelController.action(for: try keyEvent(kVK_Escape), isSearchFocused: false), .close)
        XCTAssertEqual(PanelController.action(for: try keyEvent(kVK_ANSI_1, flags: .command), isSearchFocused: false), .pasteAtIndex(0))
    }

    func testEveryQuickPasteShortcutMapsToVisiblePosition() throws {
        let codes = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        for (index, code) in codes.enumerated() {
            XCTAssertEqual(PanelController.action(for: try keyEvent(code, flags: .command), isEditingText: true), .pasteAtIndex(index))
            XCTAssertNil(PanelController.action(for: try keyEvent(code, flags: [.command, .shift])))
        }
        XCTAssertNil(PanelController.action(for: try keyEvent(kVK_ANSI_0, flags: .command)))
        XCTAssertEqual(PanelController.action(for: try keyEvent(kVK_ANSI_1, flags: [.command, .capsLock])), .pasteAtIndex(0))
    }

    func testInvalidSavedShortcutFallsBackToDefault() throws {
        let name = "ClippaTests.invalidShortcut.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(Data("invalid".utf8), forKey: "showPanelShortcut")
        XCTAssertEqual(AppSettings(defaults: defaults).showPanelShortcut, .defaultShowPanel)
        defaults.set(try JSONEncoder().encode(HotKeyShortcut(keyCode: 999, modifiers: 0)), forKey: "showPanelShortcut")
        XCTAssertEqual(AppSettings(defaults: defaults).showPanelShortcut, .defaultShowPanel)
    }

    private func keyEvent(_ code: Int, flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
            windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(code)))
    }

    private func isolatedHistory() -> EncryptedHistoryStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ClippaTests.\(UUID().uuidString)")
        return EncryptedHistoryStore(
            fileURL: root.appendingPathComponent("history.aesgcm"),
            keyStore: LocalHistoryKeyStore(fallbackURL: root.appendingPathComponent("history.key"))
        )
    }

    private func makeStore(policy: ClipboardHistoryPolicy = .default) -> ClipboardStore {
        ClipboardStore(historyStore: isolatedHistory(), policy: policy)
    }

    func testCreatesSupportedItemKinds() {
        let file = FileReference(url: URL(fileURLWithPath: "/tmp/example.txt"))
        XCTAssertEqual(ClipboardItem(payload: .text("hello")).kind, .text)
        XCTAssertEqual(ClipboardItem(payload: .url(URL(string: "https://example.com")!)).kind, .url)
        XCTAssertEqual(ClipboardItem(payload: .image(data: Data([1, 2, 3]), uti: "public.tiff")).kind, .image)
        XCTAssertEqual(ClipboardItem(payload: .files([file])).kind, .files)
    }

    func testDeduplicatesAndMovesExistingItemToTop() {
        let store = makeStore()
        let old = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        store.add(payload: .text("same"), sourceBundleIdentifier: "a", date: old)
        store.add(payload: .text("same"), sourceBundleIdentifier: "b", date: newer)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.createdAt, newer)
        XCTAssertEqual(store.items.first?.sourceBundleIdentifier, "b")
    }

    func testUsingOlderItemMovesItToFirstPlace() {
        let store = makeStore()
        store.add(payload: .text("old"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 10))
        store.add(payload: .text("new"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 20))

        let oldItem = store.items.first { $0.preview == "old" }!
        store.use(oldItem, date: Date(timeIntervalSince1970: 30))

        XCTAssertEqual(store.items.map(\.preview), ["old", "new"])
        XCTAssertEqual(
            store.items.first { $0.preview == "old" }?.lastUsedAt,
            Date(timeIntervalSince1970: 30)
        )
    }

    func testPinnedItemsAppearInAllAndKindFiltersWithRecentOrder() {
        let store = makeStore()
        let now = Date()
        store.add(payload: .text("old"), sourceBundleIdentifier: nil, date: now.addingTimeInterval(-1))
        store.add(payload: .text("new"), sourceBundleIdentifier: nil, date: now)
        store.select(store.items.last!)
        store.togglePinSelected()

        XCTAssertEqual(store.items.first?.preview, "new")
        XCTAssertEqual(store.filteredItems(query: "", filter: .all).map(\.preview), ["new", "old"])
        XCTAssertEqual(store.filteredItems(query: "", filter: .text).map(\.preview), ["new", "old"])
        XCTAssertEqual(store.filteredItems(query: "", filter: .pinned).map(\.preview), ["old"])
    }

    func testItemScopedPinAndDeleteActionsSelectTargetItem() {
        let store = makeStore()
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
        let store = makeStore()
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
        let store = makeStore()
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
        let store = makeStore()
        for index in 0..<120 {
            store.add(payload: .text("item \(index)"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: TimeInterval(index)))
        }
        XCTAssertEqual(store.items.filter { !$0.isPinned }.count, 100)
        XCTAssertEqual(store.items.first?.preview, "item 119")
    }

    func testConfigurableHistoryLimitIsApplied() {
        let store = makeStore(
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
        let store = makeStore(
            policy: ClipboardHistoryPolicy(retention: .forever, limit: .oneHundred)
        )
        store.add(payload: .text("old"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 0))
        store.applyOrderingAndRetention(now: Date(timeIntervalSince1970: 365 * 24 * 60 * 60))

        XCTAssertEqual(store.items.map(\.preview), ["old"])
    }

    func testRetentionKeepsPinnedAndRemovesOldUnpinned() {
        let store = makeStore()
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
        let store = makeStore()
        let old = Date(timeIntervalSince1970: 0)
        let recent = Date(timeIntervalSince1970: 8 * 24 * 60 * 60)
        store.add(payload: .text("old but used"), sourceBundleIdentifier: nil, date: old)

        let item = store.items.first!
        store.use(item, date: recent)

        XCTAssertEqual(store.items.first?.preview, "old but used")
        XCTAssertEqual(store.items.first?.lastUsedAt, recent)
    }

    func testSearchAndFilters() {
        let store = makeStore()
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
        XCTAssertEqual(store.filteredItems(query: "alpha", filter: .all).count, 1)
        XCTAssertEqual(store.filteredItems(query: "alpha", filter: .text).count, 1)
    }

    func testAdvancedSearchTokens() {
        let store = makeStore()
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
        let source = makeStore()
        source.add(payload: .text("pinned"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1))
        source.add(payload: .text("regular"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 2))
        source.togglePin(source.items.first { $0.preview == "pinned" }!)

        let data = try source.exportPinnedData()
        let target = makeStore()
        let imported = try target.importPinnedData(data, date: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(target.items.first?.preview, "pinned")
        XCTAssertTrue(target.items.first?.isPinned == true)
        XCTAssertTrue(try target.importPinnedData(data).isEmpty)
    }

    func testDerivedVisibleStateUpdatesOnlyWhenVisibleItemsChange() {
        let store = makeStore()
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
        XCTAssertEqual(store.visibleItems.count, 1)
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

    func testKeyStoreUsesExistingLocalKeyWithoutKeychainPrompt() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClippaTests.\(UUID().uuidString)", isDirectory: true)
        let keyURL = folder.appendingPathComponent("history.key")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let key = Data(repeating: 7, count: 32)
        try key.write(to: keyURL)

        let store = LocalHistoryKeyStore(fallbackURL: keyURL)
        let loaded = try await store.loadOrCreateKey()

        XCTAssertEqual(loaded, key)
        try? FileManager.default.removeItem(at: folder)
    }

    func testKeyStoreCreatesLocalKeyFile() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClippaTests.\(UUID().uuidString)", isDirectory: true)
        let keyURL = folder.appendingPathComponent("history.key")

        let store = LocalHistoryKeyStore(fallbackURL: keyURL)
        let key = try await store.loadOrCreateKey()
        let saved = try Data(contentsOf: keyURL)
        let attributes = try FileManager.default.attributesOfItem(atPath: keyURL.path)

        XCTAssertEqual(key.count, 32)
        XCTAssertEqual(saved, key)
        XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o600)
        try? FileManager.default.removeItem(at: folder)
    }

    func testWrongKeyFailsAESGCMOpen() throws {
        let payload = Data("private".utf8)
        let box = try AES.GCM.seal(payload, using: SymmetricKey(size: .bits256))
        let combined = try XCTUnwrap(box.combined)
        XCTAssertThrowsError(try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: SymmetricKey(size: .bits256)))
    }

    func testShowPanelShortcutSurvivesRestart() throws {
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

        settings = AppSettings(defaults: defaults)
        XCTAssertEqual(
            settings.historyPolicy,
            ClipboardHistoryPolicy(retention: .oneMonth, limit: .fiveHundred)
        )

        defaults.removePersistentDomain(forName: suiteName)
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
        let store = makeStore()

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
