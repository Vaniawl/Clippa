import AppKit

@main
struct ClippaApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let appState = AppState()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard NSClassFromString("XCTestCase") == nil else { return }
        appState.onMenuBarVisibilityChange = { [weak self] in
            self?.updateStatusItem()
        }
        updateStatusItem()
        appState.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appState.refreshAccessibilityState()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if appState.templateWindowController.activateIfVisible() { return false }
        appState.showSettings()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        appState.monitor.stop()
        appState.hotKeyService.unregister()
        return .terminateNow
    }

    private func updateStatusItem() {
        if appState.settings.showsMenuBarIcon {
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Clippa")
            item.button?.setAccessibilityLabel("Clippa")
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let state = appState
        menu.removeAllItems()
        menu.addItem(menuItem(String(localized: "Show Clipboard History"), symbol: "doc.on.clipboard") {
            state.panelController.show(appState: state)
        })
        menu.addItem(.separator())

        if state.settings.isCapturePaused {
            menu.addItem(menuItem(state.settings.capturePauseDescription, symbol: "pause.circle.fill") {
                state.monitor.resumeCapture()
            })
        } else {
            let pause = menuItem(String(localized: "Pause History"), symbol: "pause.circle")
            let durations = NSMenu()
            durations.addItem(menuItem(String(localized: "15 Minutes")) { state.monitor.pauseCapture(for: 15 * 60) })
            durations.addItem(menuItem(String(localized: "1 Hour")) { state.monitor.pauseCapture(for: 60 * 60) })
            durations.addItem(menuItem(String(localized: "Until Tomorrow")) { state.monitor.pauseCapture(for: 24 * 60 * 60) })
            pause.submenu = durations
            menu.addItem(pause)
        }
        menu.addItem(.separator())

        if !state.isAutoPasteReady {
            menu.addItem(menuItem(String(localized: "Auto-Paste Needs Access"), symbol: "accessibility") {
                AccessibilityService.openSystemSettings()
            })
            menu.addItem(.separator())
        }

        if state.canUndoHistoryAction {
            menu.addItem(menuItem(String(localized: "Undo History Change"), symbol: "arrow.uturn.backward", key: "z") {
                state.undoLastHistoryAction()
            })
            menu.addItem(.separator())
        }

        menu.addItem(menuItem(String(localized: "New Template"), symbol: "text.badge.plus", key: "n") {
            state.editTemplate()
        })
        menu.addItem(menuItem(String(localized: "Settings"), symbol: "gearshape", key: ",") {
            state.showSettings()
        })
        menu.addItem(.separator())
        menu.addItem(menuItem(String(localized: "Quit Clippa"), symbol: "power", key: "q") {
            state.quit()
        })
    }

    private func menuItem(
        _ title: String,
        symbol: String? = nil,
        key: String = "",
        action: (@MainActor () -> Void)? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action == nil ? nil : #selector(performMenuAction), keyEquivalent: key)
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        item.target = self
        item.representedObject = action
        return item
    }

    @objc private func performMenuAction(_ sender: NSMenuItem) {
        (sender.representedObject as? @MainActor () -> Void)?()
    }
}
