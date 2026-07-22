import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

struct PasteTarget {
    let application: NSRunningApplication?
    let focusedElement: AXUIElement?
}

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

    func paste(_ item: ClipboardItem, into target: PasteTarget?) async -> PasteOutcome {
        copyPayload(item.payload)
        guard AccessibilityService.isTrusted else {
            return .copiedOnlyRequiresAccessibility
        }

        if let text = directInsertText(for: item), insert(text, into: target?.focusedElement) {
            return .pasted
        }

        await activatePasteTarget(target?.application)
        await sendCommandV(to: target?.application)
        return .pasted
    }

    func paste(_ item: ClipboardItem, into application: NSRunningApplication?) async -> PasteOutcome {
        await paste(item, into: PasteTarget(application: application, focusedElement: nil))
    }

    private func directInsertText(for item: ClipboardItem) -> String? {
        switch item.payload {
        case .text(let value):
            value
        case .url(let url):
            url.absoluteString
        case .image, .files:
            nil
        }
    }

    private func insert(_ text: String, into element: AXUIElement?) -> Bool {
        guard let element else {
            return false
        }
        if AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        ) == .success {
            return true
        }

        guard let range = selectedTextRange(in: element),
              let currentValue = stringValue(in: element),
              let replacementRange = stringRange(for: range, in: currentValue)
        else {
            return false
        }

        let updatedValue = currentValue.replacingCharacters(in: replacementRange, with: text)
        guard AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            updatedValue as CFTypeRef
        ) == .success else {
            return false
        }

        var caretRange = CFRange(location: range.location + text.utf16.count, length: 0)
        guard let caretValue = AXValueCreate(.cfRange, &caretRange) else {
            return true
        }
        _ = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, caretValue)
        return true
    }

    private func selectedTextRange(in element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        ) == .success, let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private func stringValue(in element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? String
    }

    private func stringRange(for range: CFRange, in value: String) -> Range<String.Index>? {
        guard range.location >= 0, range.length >= 0 else {
            return nil
        }
        let utf16 = value.utf16
        guard let lowerUTF16 = utf16.index(
            utf16.startIndex,
            offsetBy: range.location,
            limitedBy: utf16.endIndex
        ),
            let upperUTF16 = utf16.index(
                lowerUTF16,
                offsetBy: range.length,
                limitedBy: utf16.endIndex
            ),
            let lower = String.Index(lowerUTF16, within: value),
            let upper = String.Index(upperUTF16, within: value)
        else {
            return nil
        }
        return lower..<upper
    }

    private func activatePasteTarget(_ application: NSRunningApplication?) async {
        guard let application, !application.isTerminated else {
            try? await Task.sleep(for: .milliseconds(120))
            return
        }

        _ = application.activate()

        for _ in 0..<10 {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                try? await Task.sleep(for: .milliseconds(90))
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }

        try? await Task.sleep(for: .milliseconds(120))
    }

    private func sendCommandV(to application: NSRunningApplication?) async {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else {
            return
        }
        down.flags = CGEventFlags.maskCommand
        up.flags = CGEventFlags.maskCommand

        if let application, !application.isTerminated {
            down.postToPid(application.processIdentifier)
            try? await Task.sleep(for: .milliseconds(35))
            up.postToPid(application.processIdentifier)
        } else {
            down.post(tap: CGEventTapLocation.cghidEventTap)
            try? await Task.sleep(for: .milliseconds(35))
            up.post(tap: CGEventTapLocation.cghidEventTap)
        }
    }
}

enum PasteOutcome {
    case pasted
    case copiedOnlyRequiresAccessibility
}
