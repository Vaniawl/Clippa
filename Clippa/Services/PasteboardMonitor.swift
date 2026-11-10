import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
@Observable
final class PasteboardMonitor {
    private let pasteboard: NSPasteboard
    private let store: ClipboardStore
    private let settings: AppSettings
    private var timer: Timer?
    private static let pollingInterval: TimeInterval = 0.35
    private var lastChangeCount: Int
    private var internalChangeCount: Int?

    init(pasteboard: NSPasteboard = .general, store: ClipboardStore, settings: AppSettings) {
        self.pasteboard = pasteboard
        self.store = store
        self.settings = settings
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        lastChangeCount = pasteboard.changeCount
        internalChangeCount = nil

        let timer: Timer
        if let pauseUntil = settings.pauseCaptureUntil, pauseUntil > Date() {
            timer = Timer(fire: pauseUntil, interval: 0, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.start() }
            }
        } else {
            timer = Timer(timeInterval: Self.pollingInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
            timer.tolerance = 0.05
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pauseCapture(for interval: TimeInterval) {
        settings.pauseCapture(for: interval)
        if timer != nil { start() }
    }

    func resumeCapture() {
        settings.resumeCapture()
        if timer != nil { start() }
    }

    func noteInternalWrite(changeCount: Int) {
        internalChangeCount = changeCount
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else {
            return
        }
        lastChangeCount = current

        let isInternalWrite = current == internalChangeCount
        internalChangeCount = nil
        guard !isInternalWrite else {
            return
        }
        guard !settings.isCapturePaused else {
            return
        }
        let sourceBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let types = pasteboard.types ?? []
        let filter = PrivacyFilter(excludedBundleIdentifiers: settings.excludedBundleIdentifiers)
        guard filter.shouldCapture(types: types, sourceBundleIdentifier: sourceBundleIdentifier),
              let payload = readPayload(from: pasteboard)?.cleaned(
                normalizeText: settings.normalizeCopiedText,
                removeTrackingParameters: settings.removeTrackingParametersFromLinks
              ) else {
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
