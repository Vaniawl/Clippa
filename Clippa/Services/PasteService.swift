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

    func paste(
        _ item: ClipboardItem,
        into target: PasteTarget?,
        addTrailingSpace: Bool = false
    ) async -> PasteOutcome {
        copyPayload(item.payload)
        guard AccessibilityService.isTrusted else {
            return .copiedOnlyRequiresAccessibility
        }
        guard let application = target?.application, !application.isTerminated else {
            return .copiedOnlyPasteUnavailable
        }

        guard await activatePasteTarget(application) else {
            return .copiedOnlyPasteUnavailable
        }
        let focusedElement = AccessibilityService.focusedEditableTextElement(in: application) ?? target?.focusedElement
        await restoreFocus(focusedElement, in: application)
        guard await sendCommandV(to: application) else {
            return .copiedOnlyPasteUnavailable
        }
        if Self.shouldAddTrailingSpace(to: item.payload, enabled: addTrailingSpace) {
            _ = await sendSpace(to: application)
        }
        return .pasted
    }

    func paste(
        _ item: ClipboardItem,
        into application: NSRunningApplication?,
        addTrailingSpace: Bool = false
    ) async -> PasteOutcome {
        await paste(
            item,
            into: PasteTarget(application: application, focusedElement: nil),
            addTrailingSpace: addTrailingSpace
        )
    }

    static func shouldAddTrailingSpace(to payload: ClipboardPayload, enabled: Bool) -> Bool {
        guard enabled else {
            return false
        }
        switch payload {
        case .text, .url:
            return true
        case .image, .files:
            return false
        }
    }

    private func focus(_ element: AXUIElement?) {
        guard let element else {
            return
        }
        _ = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
    }

    private func restoreFocus(_ element: AXUIElement?, in application: NSRunningApplication) async {
        guard !application.isTerminated else {
            return
        }

        if NSWorkspace.shared.frontmostApplication?.processIdentifier != application.processIdentifier {
            _ = await activatePasteTarget(application)
        }

        focus(element)
        try? await Task.sleep(for: .milliseconds(35))
    }

    private func activatePasteTarget(_ application: NSRunningApplication?) async -> Bool {
        guard let application, !application.isTerminated else {
            try? await Task.sleep(for: .milliseconds(120))
            return false
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        _ = AXUIElementSetAttributeValue(
            appElement,
            kAXFrontmostAttribute as CFString,
            kCFBooleanTrue
        )
        _ = AXUIElementPerformAction(appElement, kAXRaiseAction as CFString)
        application.activate(options: [.activateAllWindows])

        for _ in 0..<14 {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
                try? await Task.sleep(for: .milliseconds(45))
                return true
            }
            try? await Task.sleep(for: .milliseconds(50))
        }

        try? await Task.sleep(for: .milliseconds(180))
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier
    }

    private func postCommandV(with post: (CGEvent) -> Void) async -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0
        guard
            let commandDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: true),
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false),
            let commandUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Command), keyDown: false)
        else {
            return false
        }
        commandDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand

        for event in [commandDown, vDown, vUp, commandUp] {
            post(event)
            try? await Task.sleep(for: .milliseconds(10))
        }
        return true
    }

    private func sendCommandV(to application: NSRunningApplication) async -> Bool {
        if await postCommandV(with: { event in
            event.post(tap: .cghidEventTap)
        }) {
            return true
        }
        return await postCommandV(with: { event in
            event.postToPid(application.processIdentifier)
        })
    }

    private func sendSpace(to application: NSRunningApplication) async -> Bool {
        try? await Task.sleep(for: .milliseconds(80))
        let source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0
        guard
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_Space),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_Space),
                keyDown: false
            )
        else {
            return false
        }

        if NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier {
            keyDown.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(10))
            keyUp.post(tap: .cghidEventTap)
        } else {
            keyDown.postToPid(application.processIdentifier)
            try? await Task.sleep(for: .milliseconds(10))
            keyUp.postToPid(application.processIdentifier)
        }
        return true
    }
}

enum PasteOutcome: Equatable {
    case pasted
    case copiedOnlyRequiresAccessibility
    case copiedOnlyPasteUnavailable
}
