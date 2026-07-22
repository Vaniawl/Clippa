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

    var notice: String?

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
        hotKeyService.register { [weak self] in
            self?.togglePanel()
        }
        if !settings.hasShownAccessibilityOnboarding && !AccessibilityService.isTrusted {
            settings.hasShownAccessibilityOnboarding = true
            notice = String(localized: "Accessibility access enables automatic paste. Without it, Clippa still copies the selected item.")
            AccessibilityService.requestPrompt()
        }
    }

    func togglePanel() {
        panelController.toggle(appState: self)
    }

    func pasteSelectedItem() {
        guard let id = store.selectedItemID, let item = store.visibleItems.first(where: { $0.id == id }) else {
            return
        }
        Task {
            await paste(item)
        }
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
        case .togglePin:
            store.togglePinSelected()
        case .delete:
            store.deleteSelected()
        }
    }

    func paste(_ item: ClipboardItem) async {
        let target = panelController.previousApplication
        store.use(item)
        panelController.close()
        let outcome = await pasteService.paste(item, into: target)
        if outcome == .copiedOnlyRequiresAccessibility {
            notice = String(localized: "Copied. Enable Accessibility access for automatic paste.")
        }
    }

    func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func quit() {
        NSApp.terminate(nil)
    }
}

@MainActor
final class PanelController {
    private var panel: ClippaPanel?
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private(set) var previousApplication: NSRunningApplication?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func toggle(appState: AppState) {
        isVisible ? close() : show(appState: appState)
    }

    func show(appState: AppState) {
        previousApplication = NSWorkspace.shared.frontmostApplication
        appState.store.searchQuery = ""
        appState.store.selectedFilter = .all
        if let first = appState.store.visibleItems.first ?? appState.store.items.first {
            appState.store.select(first)
        }

        let content = PanelView(
            store: appState.store,
            notice: appState.notice,
            onPasteSelected: { [weak appState] in appState?.pasteSelectedItem() },
            onTogglePin: { [weak appState] in appState?.store.togglePinSelected() },
            onDelete: { [weak appState] in appState?.store.deleteSelected() },
            onClose: { [weak self] in self?.close() }
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
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
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
    }

    private func installMonitors(appState: AppState) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak appState] event in
            guard let action = Self.action(for: event) else {
                return event
            }
            Task { @MainActor in
                appState?.performPanelAction(action)
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
        let command = event.modifierFlags.contains(.command)
        switch (event.keyCode, command) {
        case (UInt16(kVK_DownArrow), _):
            return .selectNext
        case (UInt16(kVK_UpArrow), _):
            return .selectPrevious
        case (UInt16(kVK_Return), _), (UInt16(kVK_ANSI_KeypadEnter), _):
            return .paste
        case (UInt16(kVK_Escape), _):
            return .close
        case (UInt16(kVK_ANSI_P), true):
            return .togglePin
        case (UInt16(kVK_Delete), true), (UInt16(kVK_ForwardDelete), true):
            return .delete
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
    case togglePin
    case delete
}

final class ClippaPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
