import AppKit
import Carbon.HIToolbox
import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    let settings: AppSettings
    let store: ClipboardStore
    let hotKeyService: GlobalHotKeyService
    let monitor: PasteboardMonitor
    let pasteService: PasteService
    let panelController = PanelController()
    let settingsWindowController = SettingsWindowController()

    var isAutoPasteReady: Bool {
        AccessibilityService.isTrusted
    }

    init() {
        let settings = AppSettings()
        let store = ClipboardStore()
        let monitor = PasteboardMonitor(store: store, settings: settings)
        self.settings = settings
        self.store = store
        self.monitor = monitor
        self.hotKeyService = GlobalHotKeyService()
        self.pasteService = PasteService(monitor: monitor)
    }

    func start() {
        Task {
            await store.load()
        }
        monitor.start()
        registerShowPanelShortcut()
        if !settings.hasShownAccessibilityOnboarding && !AccessibilityService.isTrusted {
            settings.hasShownAccessibilityOnboarding = true
            AccessibilityService.requestPrompt()
        }
    }

    func registerShowPanelShortcut() {
        hotKeyService.register(shortcut: settings.showPanelShortcut) { [weak self] in
            self?.togglePanelFromShortcut()
        }
    }

    func togglePanelFromShortcut() {
        panelController.toggle(appState: self, requiresEditableTarget: true)
    }

    func pasteSelectedItem() {
        guard let id = store.selectedItemID, let item = store.visibleItems.first(where: { $0.id == id }) else {
            return
        }
        Task {
            await paste(item)
        }
    }

    func showSettings() {
        settingsWindowController.show(appState: self)
    }

    func performPanelAction(_ action: PanelKeyAction) {
        switch action {
        case .selectNext:
            store.selectNext()
        case .selectPrevious:
            store.selectPrevious()
        case .paste:
            pasteSelectedItem()
        case .close:
            panelController.close()
        }
    }

    func paste(_ item: ClipboardItem) async {
        let target = panelController.pasteTarget
        await paste(item, into: target)
    }

    func paste(_ item: ClipboardItem, into target: PasteTarget?) async {
        let target = target
        store.use(item)
        panelController.close()
        try? await Task.sleep(for: .milliseconds(35))
        let outcome = await pasteService.paste(item, into: target)
        switch outcome {
        case .pasted:
            break
        case .copiedOnlyRequiresAccessibility:
            break
        case .copiedOnlyPasteUnavailable:
            break
        }
    }

    func quit() {
        Task {
            await store.flushPendingSave()
            NSApp.terminate(nil)
        }
    }
}

@MainActor
final class PanelController {
    private var panel: ClippaPanel?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private(set) var pasteTarget: PasteTarget?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func toggle(appState: AppState, requiresEditableTarget: Bool) {
        isVisible ? close() : show(appState: appState, requiresEditableTarget: requiresEditableTarget)
    }

    func show(appState: AppState, requiresEditableTarget: Bool = false) {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let targetApplication = frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : frontmostApplication
        let focusedElement = AccessibilityService.focusedEditableTextElement(in: targetApplication)
        if requiresEditableTarget, focusedElement == nil {
            if !AccessibilityService.isTrusted {
                AccessibilityService.requestPrompt()
            }
            NSSound.beep()
            return
        }

        if frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier {
            pasteTarget = PasteTarget(application: frontmostApplication, focusedElement: focusedElement)
        }
        appState.store.searchQuery = ""
        appState.store.selectedFilter = .all
        if let first = appState.store.visibleItems.first ?? appState.store.items.first {
            appState.store.select(first)
        }

        let content = PanelView(
            store: appState.store,
            onPasteSelected: { [weak appState] in appState?.pasteSelectedItem() }
        )
        let hostingView = NSHostingView(rootView: content)
        let size = NSSize(width: DesignSystem.panelWidth, height: DesignSystem.panelHeight)
        let frame = Self.panelFrame(near: NSEvent.mouseLocation, size: size, screens: NSScreen.screens)
        let panel = ClippaPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = hostingView
        self.panel = panel

        installMonitors(appState: appState)
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func close() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
        pasteTarget = nil
    }

    private func installMonitors(appState: AppState) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appState] event in
            guard let appState, let action = Self.action(for: event) else {
                return event
            }
            Task { @MainActor in
                appState.performPanelAction(action)
            }
            return nil
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.close()
            }
        }
    }

    private static func action(for event: NSEvent) -> PanelKeyAction? {
        switch event.keyCode {
        case UInt16(kVK_DownArrow):
            return .selectNext
        case UInt16(kVK_UpArrow):
            return .selectPrevious
        case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
            return .paste
        case UInt16(kVK_Escape):
            return .close
        default:
            return nil
        }
    }

    static func panelFrame(near point: NSPoint, size: NSSize, screens: [NSScreen]) -> NSRect {
        let fallback = screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let screen = screens.first { $0.frame.contains(point) } ?? fallbackScreen(from: screens, fallback: fallback)
        let visible = screen.visibleFrame
        let margin: CGFloat = 12
        var x = point.x + margin
        var y = point.y - size.height - margin

        if x + size.width > visible.maxX {
            x = point.x - size.width - margin
        }
        if y < visible.minY {
            y = point.y + margin
        }
        x = min(max(x, visible.minX + margin), visible.maxX - size.width - margin)
        y = min(max(y, visible.minY + margin), visible.maxY - size.height - margin)
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private static func fallbackScreen(from screens: [NSScreen], fallback: NSRect) -> NSScreen {
        if let screen = screens.first(where: { $0.visibleFrame == fallback }) {
            return screen
        }
        return screens.first ?? NSScreen()
    }
}

enum PanelKeyAction: Sendable {
    case selectNext
    case selectPrevious
    case paste
    case close
}

final class ClippaPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
