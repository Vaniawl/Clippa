import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class PasteService {
    private let pasteboard: NSPasteboard
    private let monitor: PasteboardMonitor

    init(pasteboard: NSPasteboard = .general, monitor: PasteboardMonitor) {
        self.pasteboard = pasteboard
        self.monitor = monitor
    }

    func copyPayload(_ payload: ClipboardPayload) {
        pasteboard.clearContents()
        switch payload {
        case .text(let value):
            pasteboard.setString(value, forType: .string)
        case .url(let url):
            pasteboard.writeObjects([url as NSURL])
            pasteboard.setString(url.absoluteString, forType: .string)
        case .image(let data, _):
            if let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        case .files(let refs):
            let urls = refs.map { $0.url as NSURL }
            pasteboard.writeObjects(urls)
        }
        monitor.noteInternalWrite(changeCount: pasteboard.changeCount)
    }

    func paste(_ item: ClipboardItem, into application: NSRunningApplication?) async -> PasteOutcome {
        copyPayload(item.payload)
        guard AccessibilityService.isTrusted else {
            return .copiedOnlyRequiresAccessibility
        }

        application?.activate()
        try? await Task.sleep(for: .milliseconds(140))
        sendCommandV()
        return .pasted
    }

    private func sendCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else {
            return
        }
        down.flags = CGEventFlags.maskCommand
        up.flags = CGEventFlags.maskCommand
        down.post(tap: CGEventTapLocation.cghidEventTap)
        up.post(tap: CGEventTapLocation.cghidEventTap)
    }
}

enum PasteOutcome {
    case pasted
    case copiedOnlyRequiresAccessibility
}
