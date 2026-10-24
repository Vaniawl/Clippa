import AppKit
import Carbon.HIToolbox
import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
    let launchAtLoginController = LaunchAtLoginController()
    let previewController = ClipboardPreviewController()
    let pasteFailureController = PasteFailureController()
    let templateWindowController = TemplateWindowController()
    private var isPasting = false
    private var isExtractingText = false
    private var undoHistory: [[ClipboardItem]] = []
    private(set) var isAutoPasteReady = AccessibilityService.isTrusted

    var canUndoHistoryAction: Bool {
        !undoHistory.isEmpty
    }

    init() {
        let settings = AppSettings()
        let store = ClipboardStore(policy: settings.historyPolicy)
        let monitor = PasteboardMonitor(store: store, settings: settings)
        self.settings = settings
        self.store = store
        self.monitor = monitor
        self.hotKeyService = GlobalHotKeyService()
        self.pasteService = PasteService(monitor: monitor)
    }

    func start() {
        refreshAccessibilityState()
        Task {
            await store.load()
            monitor.start()
        }
        registerShowPanelShortcut()
        if !settings.hasShownAccessibilityOnboarding && !AccessibilityService.isTrusted {
            settings.hasShownAccessibilityOnboarding = true
            AccessibilityService.requestPrompt()
        }
    }

    func refreshAccessibilityState() {
        isAutoPasteReady = AccessibilityService.isTrusted
    }

    func registerShowPanelShortcut() {
        hotKeyService.register(shortcut: settings.showPanelShortcut) { [weak self] in
            self?.togglePanelFromShortcut()
        }
    }

    func togglePanelFromShortcut() {
        panelController.toggle(appState: self, requiresEditableTarget: false)
    }

    func pasteSelectedItem() {
        guard let id = store.selectedItemID, let item = store.visibleItems.first(where: { $0.id == id }) else {
            return
        }
        Task {
            await paste(item)
        }
    }

    func editTemplate(_ item: ClipboardItem? = nil) {
        let id = item?.isTemplate == true ? item?.id : nil
        panelController.close()
        templateWindowController.edit(item: item) { [weak self] title, folder, body in
            guard let self else { return }
            try self.store.saveTemplate(id: id, title: title, folder: folder, body: body)
        }
    }

    func showSettings() {
        settingsWindowController.show(appState: self)
    }

    func setHistoryRetention(_ retention: HistoryRetention) {
        settings.historyRetention = retention
        recordUndo(store.updatePolicy(settings.historyPolicy))
    }

    func setHistoryLimit(_ limit: HistoryLimit) {
        settings.historyLimit = limit
        recordUndo(store.updatePolicy(settings.historyPolicy))
    }

    func copy(_ item: ClipboardItem) {
        pasteService.copyPayload(item.payload)
        store.use(item)
    }

    func preview(_ item: ClipboardItem) {
        previewController.show(item)
    }

    func open(_ item: ClipboardItem) {
        let url: URL?
        switch item.payload {
        case .url(let itemURL):
            url = itemURL
        case .files(let references):
            url = references.first(where: \.exists)?.url
        default:
            url = nil
        }
        guard let url else {
            NSSound.beep()
            return
        }
        panelController.close()
        NSWorkspace.shared.open(url)
    }

    func extractText(_ item: ClipboardItem) {
        guard !isExtractingText, case .image(let data, _) = item.payload else {
            NSSound.beep()
            return
        }
        isExtractingText = true
        store.storageMessage = nil
        Task {
            defer { isExtractingText = false }
            let text = await ImageTextExtractor.recognizeText(in: data)
            guard !text.isEmpty else {
                store.storageMessage = String(localized: "No text was found in this image. Try a clearer image or another clip.")
                return
            }
            store.add(
                payload: .text(text),
                sourceBundleIdentifier: Bundle.main.bundleIdentifier,
                date: Date()
            )
            store.selectedFilter = .text
        }
    }

    func togglePin(_ item: ClipboardItem) {
        store.togglePin(item)
    }

    func delete(_ item: ClipboardItem) {
        guard let deleted = store.delete(item) else {
            return
        }
        recordUndo([deleted])
    }

    func clearUnpinnedHistory() {
        let removed = store.clearUnpinned()
        recordUndo(removed)
    }

    func clearAllHistory() {
        let removed = store.clearAll()
        recordUndo(removed)
    }

    func exportPinnedClips() {
        let panel = NSSavePanel()
        panel.title = String(localized: "Export Pinned Clips")
        panel.nameFieldStringValue = "Clippa Pinned Clips.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        do {
            try store.exportPinnedData().write(to: url, options: .atomic)
        } catch {
            showOperationError(title: String(localized: "Export Failed"), message: String(localized: "Pinned clips could not be exported. Choose a writable folder and try again."))
        }
    }

    func importPinnedClips() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Import Pinned Clips")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        do {
            _ = try store.importPinnedData(Data(contentsOf: url))
        } catch {
            showOperationError(title: String(localized: "Import Failed"), message: String(localized: "This file could not be imported. Choose a Clippa pinned-clips JSON export and try again."))
        }
    }

    private func showOperationError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: String(localized: "OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func undoLastHistoryAction() {
        guard let items = undoHistory.popLast() else {
            NSSound.beep()
            return
        }
        store.restore(items)
    }

    func performPanelAction(_ action: PanelKeyAction) {
        switch action {
        case .selectNext:
            store.selectNext()
        case .selectPrevious:
            store.selectPrevious()
        case .selectNextFilter:
            store.selectAdjacentFilter(offset: 1)
        case .selectPreviousFilter:
            store.selectAdjacentFilter(offset: -1)
        case .paste:
            pasteSelectedItem()
        case .pasteAtIndex(let index):
            guard let item = store.quickPasteItem(at: index) else { return }
            Task { await paste(item) }
        case .newTemplate:
            editTemplate()
        case .copy:
            withSelectedItem(copy)
        case .preview:
            withSelectedItem(preview)
        case .togglePin:
            withSelectedItem(togglePin)
        case .delete:
            withSelectedItem(delete)
        case .undo:
            undoLastHistoryAction()
        case .close:
            panelController.close()
        }
    }

    func paste(_ item: ClipboardItem) async {
        let target = panelController.pasteTarget
        guard item.isTemplate, case .text(let body) = item.payload else {
            await paste(item, into: target)
            return
        }
        if !TemplateRenderer.variables(in: body).isEmpty {
            panelController.close()
            templateWindowController.fill(item: item) { [weak self] text in
                Task { await self?.pasteTemplate(item, text: text, into: target) }
            }
        } else {
            await pasteTemplate(item, text: TemplateRenderer.render(body), into: target)
        }
    }

    private func pasteTemplate(_ item: ClipboardItem, text: String, into target: PasteTarget?) async {
        guard store.items.contains(where: { $0.id == item.id }) else { return }
        var rendered = item
        rendered.payload = .text(text)
        await paste(rendered, into: target)
    }

    func paste(_ item: ClipboardItem, into target: PasteTarget?) async {
        guard !isPasting else { return }
        isPasting = true
        defer { isPasting = false }
        let target = target
        store.use(item)
        panelController.close()
        try? await Task.sleep(for: .milliseconds(35))
        let outcome = await pasteService.paste(
            item,
            into: target,
            addTrailingSpace: settings.addSpaceAfterPaste
        )
        guard outcome != .pasted else {
            return
        }
        pasteFailureController.show(requiresAccessibility: outcome == .copiedOnlyRequiresAccessibility)
    }

    private func withSelectedItem(_ action: (ClipboardItem) -> Void) {
        guard let id = store.selectedItemID,
              let item = store.visibleItems.first(where: { $0.id == id })
        else {
            return
        }
        action(item)
    }

    private func recordUndo(_ items: [ClipboardItem]) {
        guard !items.isEmpty else {
            return
        }
        undoHistory.append(items)
        if undoHistory.count > 10 {
            undoHistory.removeFirst(undoHistory.count - 10)
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
    private var isSearchFocused = false
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
        appState.store.selectedTemplateFolder = nil
        appState.store.selectedFilter = .all
        if let first = appState.store.visibleItems.first {
            appState.store.select(first)
        }

        let content = PanelView(
            store: appState.store,
            onPasteSelected: { [weak appState] in appState?.pasteSelectedItem() },
            onCopy: { [weak appState] item in appState?.copy(item) },
            onPreview: { [weak appState] item in appState?.preview(item) },
            onOpen: { [weak appState] item in appState?.open(item) },
            onExtractText: { [weak appState] item in appState?.extractText(item) },
            onTogglePin: { [weak appState] item in appState?.togglePin(item) },
            onDelete: { [weak appState] item in appState?.delete(item) },
            onEditTemplate: { [weak appState] item in appState?.editTemplate(item) },
            onNewTemplate: { [weak appState] in appState?.editTemplate() },
            onSearchFocusChanged: { [weak self] focused in self?.isSearchFocused = focused }
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
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak appState] event in
            guard let self, let panel = self.panel, event.window === panel,
                  let appState,
                  let action = Self.action(for: event, isEditingText: panel.firstResponder is NSTextView, isSearchFocused: self.isSearchFocused) else {
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

    static func action(for event: NSEvent, isEditingText: Bool = false, isSearchFocused: Bool = true) -> PanelKeyAction? {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if modifiers == .command {
            let numberKeys: [UInt16] = [UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_3), UInt16(kVK_ANSI_4), UInt16(kVK_ANSI_5), UInt16(kVK_ANSI_6), UInt16(kVK_ANSI_7), UInt16(kVK_ANSI_8), UInt16(kVK_ANSI_9)]
            if let index = numberKeys.firstIndex(of: event.keyCode) { return .pasteAtIndex(index) }
            switch event.keyCode {
            case UInt16(kVK_ANSI_LeftBracket): return .selectPreviousFilter
            case UInt16(kVK_ANSI_RightBracket): return .selectNextFilter
            case UInt16(kVK_ANSI_N): return .newTemplate
            case UInt16(kVK_ANSI_C):
                return isEditingText ? nil : .copy
            case UInt16(kVK_ANSI_Y):
                return .preview
            case UInt16(kVK_ANSI_P):
                return .togglePin
            case UInt16(kVK_Delete), UInt16(kVK_ForwardDelete):
                return isEditingText ? nil : .delete
            case UInt16(kVK_ANSI_Z):
                return isEditingText ? nil : .undo
            default:
                break
            }
        }

        // Modified arrows/Return belong to native text editing and selection.
        guard modifiers.isEmpty else { return nil }
        if event.keyCode == UInt16(kVK_Escape) { return .close }
        guard isSearchFocused else { return nil }
        switch event.keyCode {
        case UInt16(kVK_RightArrow):
            return isEditingText ? nil : .selectNextFilter
        case UInt16(kVK_LeftArrow):
            return isEditingText ? nil : .selectPreviousFilter
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

enum PanelKeyAction: Sendable, Equatable {
    case selectNext
    case selectPrevious
    case selectNextFilter
    case selectPreviousFilter
    case paste
    case pasteAtIndex(Int)
    case newTemplate
    case copy
    case preview
    case togglePin
    case delete
    case undo
    case close
}

final class ClippaPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
