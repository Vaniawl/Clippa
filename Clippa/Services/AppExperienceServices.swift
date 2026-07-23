import AppKit
import ImageIO
import Observation
import QuickLookUI
import ServiceManagement
import UniformTypeIdentifiers
import Vision

@MainActor
@Observable
final class LaunchAtLoginController {
    private(set) var isEnabled = false
    private(set) var message: String?

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            message = nil
        } catch {
            message = String(localized: "Launch at Login could not be changed.")
        }
        refresh()
    }
}

@MainActor
final class PasteFailureController {
    private var isShowing = false

    func show(requiresAccessibility: Bool) {
        guard !isShowing else {
            return
        }
        isShowing = true
        defer { isShowing = false }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Clippa Could Not Paste")
        alert.informativeText = requiresAccessibility
            ? String(localized: "Allow Clippa in Accessibility settings to paste automatically. The item was copied to your clipboard.")
            : String(localized: "The item was copied to your clipboard. Check Accessibility permission and try again.")
        alert.addButton(withTitle: String(localized: "Open Accessibility Settings"))
        alert.addButton(withTitle: String(localized: "Not Now"))

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            AccessibilityService.openSystemSettings()
        }
    }
}

@MainActor
final class ClipboardPreviewController: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var previewURLs: [URL] = []
    private let previewDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClippaPreview", isDirectory: true)

    func show(_ item: ClipboardItem) {
        previewURLs = makePreviewURLs(for: item)
        guard !previewURLs.isEmpty, let panel = QLPreviewPanel.shared() else {
            NSSound.beep()
            return
        }

        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = 0
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURLs.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        previewURLs[index] as NSURL
    }

    func previewPanelWillClose(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
        previewURLs = []
        try? FileManager.default.removeItem(at: previewDirectory)
    }

    private func makePreviewURLs(for item: ClipboardItem) -> [URL] {
        switch item.payload {
        case .files(let references):
            return references.filter(\.exists).map(\.url)
        case .url(let url):
            return writeTemporary(
                try? PropertyListSerialization.data(
                    fromPropertyList: ["URL": url.absoluteString],
                    format: .xml,
                    options: 0
                ),
                named: "Link.webloc"
            )
        case .text(let text):
            return writeTemporary(Data(text.utf8), named: "Clipboard.txt")
        case .image(let data, let uti):
            let fileExtension = uti.flatMap { UTType($0)?.preferredFilenameExtension } ?? "tiff"
            return writeTemporary(data, named: "Clipboard.\(fileExtension)")
        }
    }

    private func writeTemporary(_ data: Data?, named name: String) -> [URL] {
        guard let data else {
            return []
        }
        do {
            try FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
            let url = previewDirectory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            return [url]
        } catch {
            return []
        }
    }
}

enum ImageTextExtractor {
    static func recognizeText(in data: Data) async -> String {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                return ""
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image)
            do {
                try handler.perform([request])
                return (request.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                return ""
            }
        }.value
    }
}
