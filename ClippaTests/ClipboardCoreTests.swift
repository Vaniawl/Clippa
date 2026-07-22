import AppKit
import CryptoKit
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

    func testPinnedItemsSortBeforeNewestUnpinned() {
        let store = ClipboardStore()
        store.add(payload: .text("old"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 1))
        store.add(payload: .text("new"), sourceBundleIdentifier: nil, date: Date(timeIntervalSince1970: 2))
        store.select(store.items.last!)
        store.togglePinSelected()
        XCTAssertEqual(store.items.first?.preview, "old")
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

    func testSearchAndFilters() {
        let store = ClipboardStore()
        store.add(payload: .text("alpha note"), sourceBundleIdentifier: nil)
        store.add(payload: .url(URL(string: "https://example.com/beta")!), sourceBundleIdentifier: nil)
        store.add(payload: .image(data: Data([1]), uti: nil), sourceBundleIdentifier: nil)
        XCTAssertEqual(store.filteredItems(query: "beta", filter: .all).count, 1)
        XCTAssertEqual(store.filteredItems(query: "", filter: .image).first?.kind, .image)
        XCTAssertEqual(store.filteredItems(query: "alpha", filter: .text).first?.preview, "alpha note")
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

    func testWrongKeyFailsAESGCMOpen() throws {
        let payload = Data("private".utf8)
        let box = try AES.GCM.seal(payload, using: SymmetricKey(size: .bits256))
        let combined = try XCTUnwrap(box.combined)
        XCTAssertThrowsError(try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: SymmetricKey(size: .bits256)))
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
