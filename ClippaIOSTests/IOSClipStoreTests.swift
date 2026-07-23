import UIKit
import XCTest
@testable import ClippaIOS

@MainActor
final class IOSClipStoreTests: XCTestCase {
    func testSaveCurrentPasteboardStoresTextAndPersists() throws {
        let defaults = try makeDefaults()
        let pasteboard = MockPasteboard()
        pasteboard.string = "Hello\nworld"

        let store = IOSClipStore(defaults: defaults, pasteboard: pasteboard)

        XCTAssertTrue(store.saveCurrentPasteboard())
        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips.first?.kind, .text)
        XCTAssertEqual(store.clips.first?.content, "Hello\nworld")

        let reloaded = IOSClipStore(defaults: defaults, pasteboard: MockPasteboard())
        XCTAssertEqual(reloaded.clips.count, 1)
        XCTAssertEqual(reloaded.clips.first?.title, "Hello world")
    }

    func testSaveCurrentPasteboardClassifiesLinksAndDeduplicates() throws {
        let defaults = try makeDefaults()
        let pasteboard = MockPasteboard()
        pasteboard.string = "https://github.com/Vaniawl/Clippa?utm_source=test&ref=chat"
        let store = IOSClipStore(defaults: defaults, pasteboard: pasteboard)

        XCTAssertTrue(store.saveCurrentPasteboard())
        XCTAssertTrue(store.saveCurrentPasteboard())

        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips.first?.kind, .link)
        XCTAssertEqual(store.clips.first?.title, "github.com")
        XCTAssertEqual(store.clips.first?.content, "https://github.com/Vaniawl/Clippa?ref=chat")
    }

    func testFilteringPinAndDelete() throws {
        let defaults = try makeDefaults()
        let pasteboard = MockPasteboard()
        let store = IOSClipStore(defaults: defaults, pasteboard: pasteboard)

        pasteboard.string = "plain text"
        XCTAssertTrue(store.saveCurrentPasteboard())

        pasteboard.string = "https://clippa.app"
        XCTAssertTrue(store.saveCurrentPasteboard())

        let textClip = try XCTUnwrap(store.clips.first { $0.kind == .text })
        let linkClip = try XCTUnwrap(store.clips.first { $0.kind == .link })

        store.selectedFilter = .text
        XCTAssertEqual(store.filteredClips(query: "").map(\.id), [textClip.id])

        store.selectedFilter = .link
        XCTAssertEqual(store.filteredClips(query: "clippa").map(\.id), [linkClip.id])

        store.togglePin(textClip)
        store.selectedFilter = .pinned
        XCTAssertEqual(store.filteredClips(query: "").map(\.id), [textClip.id])

        store.delete(textClip)
        XCTAssertFalse(store.clips.contains { $0.id == textClip.id })
    }

    func testCopyWritesSelectedClipBackToPasteboard() throws {
        let defaults = try makeDefaults()
        let pasteboard = MockPasteboard()
        pasteboard.string = "copy me"
        let store = IOSClipStore(defaults: defaults, pasteboard: pasteboard)
        XCTAssertTrue(store.saveCurrentPasteboard())

        pasteboard.string = nil
        let clip = try XCTUnwrap(store.clips.first)

        XCTAssertTrue(store.copy(clip))
        XCTAssertEqual(pasteboard.string, "copy me")
        XCTAssertNotNil(store.clips.first?.lastCopiedAt)
    }

    func testSaveImageFromPasteboard() throws {
        let defaults = try makeDefaults()
        let pasteboard = MockPasteboard()
        pasteboard.image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 6)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 6))
        }
        let store = IOSClipStore(defaults: defaults, pasteboard: pasteboard)

        XCTAssertTrue(store.saveCurrentPasteboard())
        XCTAssertEqual(store.clips.first?.kind, .image)
        XCTAssertEqual(store.clips.first?.detail, "8 x 6")
        XCTAssertNotNil(store.clips.first?.imageData)
    }

    func testReplaceAllSeedsStableSampleClips() throws {
        let defaults = try makeDefaults()
        let store = IOSClipStore(defaults: defaults, pasteboard: MockPasteboard())

        store.replaceAll(IOSClip.sampleClips)

        XCTAssertEqual(store.clips.count, 3)
        XCTAssertEqual(store.clips.first?.title, "Shipping address")
        XCTAssertTrue(store.clips.first?.isPinned == true)

        let reloaded = IOSClipStore(defaults: defaults, pasteboard: MockPasteboard())
        XCTAssertEqual(reloaded.clips.map(\.id), IOSClip.sampleClips.map(\.id))
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "ClippaIOSTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suite)
        }
        return defaults
    }
}

@MainActor
private final class MockPasteboard: IOSPasteboard {
    var string: String?
    var url: URL?
    var image: UIImage?
}
