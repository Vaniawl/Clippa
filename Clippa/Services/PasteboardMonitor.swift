import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
@Observable
final class PasteboardMonitor {
    private let pasteboard: NSPasteboard
    private let store: ClipboardStore
    private let settings: AppSettings
    private var task: Task<Void, Never>?
    private var lastChangeCount: Int
    private var internalChangeCounts: Set<Int> = []

    init(pasteboard: NSPasteboard = .general, store: ClipboardStore, settings: AppSettings) {
        self.pasteboard = pasteboard
        self.store = store
        self.settings = settings
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                await self?.poll()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func noteInternalWrite(changeCount: Int) {
        internalChangeCounts.insert(changeCount)
    }

    private func poll() async {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else {
            return
        }
        lastChangeCount = current

        if internalChangeCounts.remove(current) != nil {
            return
        }
        let sourceBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let types = pasteboard.types ?? []
        let filter = PrivacyFilter(excludedBundleIdentifiers: settings.excludedBundleIdentifiers)
        guard filter.shouldCapture(types: types, sourceBundleIdentifier: sourceBundleIdentifier),
              let payload = readPayload(from: pasteboard) else {
            return
        }
        store.add(payload: payload, sourceBundleIdentifier: sourceBundleIdentifier)
    }

    private func readPayload(from pasteboard: NSPasteboard) -> ClipboardPayload? {
        if let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [NSURL], !objects.isEmpty {
            let urls = objects.map { $0 as URL }
            return .files(urls.map { url in
                let bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                return FileReference(url: url, bookmarkData: bookmark)
            })
        }

        if let image = NSImage(pasteboard: pasteboard), let data = image.tiffRepresentation {
            return .image(data: data, uti: UTType.tiff.identifier)
        }

        if let string = pasteboard.string(forType: .string) {
            if let url = URL(string: string), let scheme = url.scheme, !scheme.isEmpty {
                return .url(url)
            }
            return .text(string)
        }
        return nil
    }
}
