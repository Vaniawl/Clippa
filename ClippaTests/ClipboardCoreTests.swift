import AppKit
import Carbon.HIToolbox
import CryptoKit
import ImageIO
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

    func testUsingOlderItemMovesItToTop() {
        let store = ClipboardStore()
        store.add(payload: .text("old"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 10))
        store.add(payload: .text("new"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 20))

        let oldItem = store.items.first { $0.preview == "old" }!
        store.use(oldItem, date: Date(timeIntervalSince1970: 30))

        XCTAssertEqual(store.items.first?.preview, "old")
        XCTAssertEqual(store.items.first?.lastUsedAt, Date(timeIntervalSince1970: 30))
    }

    func testPinnedItemsSortBeforeNewestUnpinned() {
        let store = ClipboardStore()
        store.add(payload: .text("old"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1))
        store.add(payload: .text("new"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 2))
        store.select(store.items.last!)
        store.togglePinSelected()
        XCTAssertEqual(store.items.first?.preview, "old")
    }

    func testItemScopedPinAndDeleteActionsSelectTargetItem() {
        let store = ClipboardStore()
        store.add(payload: .text("first"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1))
        store.add(payload: .text("second"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 2))
        let first = store.items.first { $0.preview == "first" }!
        let second = store.items.first { $0.preview == "second" }!

        store.select(second)
        store.togglePin(first)
        XCTAssertEqual(store.selectedItemID, first.id)
        XCTAssertTrue(store.items.first { $0.id == first.id }?.isPinned == true)

        store.delete(second)
        XCTAssertNil(store.items.first { $0.id == second.id })
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
        XCTAssertEqual(store.filteredItems(query: "alpha", filter: .text).first?.preview, "alpha note")
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
        store.togglePin(store.items.first!)
        XCTAssertEqual(store.pinnedItemCount, 1)
    }

    func testImageMetadataUsesImagePropertiesWithoutViewDecode() throws {
        let data = try makePNGData(width: 2, height: 3)
        let item = ClipboardItem(payload: .image(data: data, uti: "public.png"))

        XCTAssertEqual(item.imageMetadata?.widthPixels, 2)
        XCTAssertEqual(item.imageMetadata?.heightPixels, 3)
        XCTAssertEqual(item.imageMetadata?.byteCount, data.count)
        XCTAssertEqual(item.imageMetadata?.uti, "public.png")
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

    func testShowPanelShortcutIsAlwaysCommandShiftW() throws {
        let suiteName = "ClippaTests.shortcuts.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        var settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.showPanelShortcut.displayString, "⇧⌘W")

        settings.showPanelShortcut = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(controlKey | optionKey))

        settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.showPanelShortcut.displayString, "⇧⌘W")

        defaults.removePersistentDomain(forName: suiteName)
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
