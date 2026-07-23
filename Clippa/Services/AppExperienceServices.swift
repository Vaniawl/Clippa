import AppKit
import Observation
import QuickLookUI
import ServiceManagement
import SwiftUI
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
final class PasteFeedbackController {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(message: String, systemImage: String, tint: Color) {
        dismissTask?.cancel()
        panel?.orderOut(nil)

        let size = NSSize(width: 420, height: 64)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.minY + 42,
            width: size.width,
            height: size.height
        )

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(
            rootView: PasteFeedbackView(message: message, systemImage: systemImage, tint: tint)
        )
        self.panel = panel
        panel.orderFrontRegardless()

        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else {
                return
            }
            self?.panel?.orderOut(nil)
            self?.panel = nil
        }
    }
}

private struct PasteFeedbackView: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)

            Text(message)
                .font(.callout.weight(.medium))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(width: 420, height: 64)
        .background(.regularMaterial, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.10))
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
