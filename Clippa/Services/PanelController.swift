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
            notice = String(localized: "Accessibility access enables automatic paste. Without it, Clippa still copies the selected item.")
            AccessibilityService.requestPrompt()
        }
    }

    func registerShowPanelShortcut() {
        hotKeyService.register(shortcut: settings.showPanelShortcut) { [weak self] in
            self?.togglePanel()
        }
    }

    func updateShowPanelShortcut(_ shortcut: HotKeyShortcut) {
        settings.showPanelShortcut = shortcut
        registerShowPanelShortcut()
    }

    func updatePinShortcut(_ shortcut: HotKeyShortcut) {
        settings.pinShortcut = shortcut
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

    func copySelectedItem() {
        guard let id = store.selectedItemID, let item = store.visibleItems.first(where: { $0.id == id }) else {
            return
        }
        copy(item)
    }

    func performPanelAction(_ action: PanelKeyAction) {
        switch action {
        case .selectNext:
            store.selectNext()
        case .selectPrevious:
            store.selectPrevious()
        case .paste:
            pasteSelectedItem()
        case .copy:
            copySelectedItem()
        case .open:
            openSelectedItem()
        case .reveal:
            revealSelectedItem()
        case .closeOrClearSearch:
            if store.searchQuery.isEmpty {
                panelController.close()
            } else {
                store.searchQuery = ""
            }
        case .togglePin:
            store.togglePinSelected()
        case .delete:
            store.deleteSelected()
        }
    }

    func paste(_ item: ClipboardItem) async {
        await paste(item, into: panelController.previousApplication)
    }

    func paste(_ item: ClipboardItem, into target: NSRunningApplication?) async {
        store.use(item)
        panelController.close()
        let outcome = await pasteService.paste(item, into: target)
        if outcome == .copiedOnlyRequiresAccessibility {
            notice = String(localized: "Copied. Enable Accessibility access for automatic paste.")
        }
    }

    func copy(_ item: ClipboardItem) {
        pasteService.copyPayload(item.payload)
        store.use(item)
        notice = String(localized: "Copied to clipboard.")
        panelController.close()
    }

    func openSelectedItem() {
        guard let id = store.selectedItemID, let item = store.visibleItems.first(where: { $0.id == id }) else {
            return
        }
        open(item)
    }

    func open(_ item: ClipboardItem) {
        switch item.payload {
        case .url(let url):
            NSWorkspace.shared.open(url)
            panelController.close()
        case .files(let refs):
            refs.filter(\.exists).forEach { NSWorkspace.shared.open($0.url) }
            panelController.close()
        case .text, .image:
            copy(item)
        }
    }

    func revealSelectedItem() {
        guard let id = store.selectedItemID, let item = store.visibleItems.first(where: { $0.id == id }) else {
            return
        }
        reveal(item)
    }

    func reveal(_ item: ClipboardItem) {
        guard case .files(let refs) = item.payload else {
            return
        }
        let urls = refs.filter(\.exists).map(\.url)
        guard !urls.isEmpty else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
        panelController.close()
    }

    func confirmClearUnpinned() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear unpinned clipboard history?")
        alert.informativeText = String(localized: "Pinned items will stay in history.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Clear unpinned history"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearUnpinned()
            notice = String(localized: "Unpinned history cleared.")
        }
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
            isAutoPasteReady: appState.isAutoPasteReady,
            showShortcutText: appState.settings.showPanelShortcut.displayString,
            pinShortcutText: appState.settings.pinShortcut.displayString,
            onPasteSelected: { [weak appState] in appState?.pasteSelectedItem() },
            onCopy: { [weak appState] item in appState?.copy(item) },
            onOpen: { [weak appState] item in appState?.open(item) },
            onReveal: { [weak appState] item in appState?.reveal(item) },
            onTogglePin: { [weak appState] item in appState?.store.togglePin(item) },
            onDelete: { [weak appState] item in appState?.store.delete(item) },
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
            guard let appState, let action = Self.action(for: event, settings: appState.settings) else {
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

    private static func action(for event: NSEvent, settings: AppSettings) -> PanelKeyAction? {
        let command = event.modifierFlags.contains(.command)
        if settings.pinShortcut.matches(event) {
            return .togglePin
        }
        switch (event.keyCode, command) {
        case (UInt16(kVK_DownArrow), _):
            return .selectNext
        case (UInt16(kVK_UpArrow), _):
            return .selectPrevious
        case (UInt16(kVK_Return), _), (UInt16(kVK_ANSI_KeypadEnter), _):
            return .paste
        case (UInt16(kVK_ANSI_C), true):
            return .copy
        case (UInt16(kVK_ANSI_O), true):
            return .open
        case (UInt16(kVK_ANSI_R), true):
            return .reveal
        case (UInt16(kVK_Escape), _):
            return .closeOrClearSearch
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
    case copy
    case open
    case reveal
    case closeOrClearSearch
    case togglePin
    case delete
}

final class ClippaPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
