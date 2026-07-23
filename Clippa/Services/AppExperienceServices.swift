import AppKit
import Observation
import QuickLookUI
import ServiceManagement
import UniformTypeIdentifiers

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
