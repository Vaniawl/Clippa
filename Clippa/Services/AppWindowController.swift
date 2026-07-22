import AppKit
import SwiftUI

@MainActor
final class AppWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var previousApplication: NSRunningApplication?

    func show(appState: AppState, selection: AppWindowSection = .history) {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        if frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApplication = frontmostApplication
        }

        let content = AppWindowView(
            settings: appState.settings,
            store: appState.store,
            hotKeyStatus: appState.hotKeyService.registrationStatus,
            initialSelection: selection,
            onShowShortcutChange: { [weak appState] shortcut in
                appState?.updateShowPanelShortcut(shortcut)
            },
            onPinShortcutChange: { [weak appState] shortcut in
                appState?.updatePinShortcut(shortcut)
            },
            onPaste: { [weak appState, weak self] item in
                Task { @MainActor in
                    await appState?.paste(item, into: self?.previousApplication)
                }
            },
            onCopy: { [weak appState] item in
                appState?.copy(item)
            },
            onOpen: { [weak appState] item in
                appState?.open(item)
            },
            onReveal: { [weak appState] item in
                appState?.reveal(item)
            }
        )

        if let window {
            window.contentView = NSHostingView(rootView: content)
            show(window)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Clippa")
        window.minSize = NSSize(width: 760, height: 500)
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        window.delegate = self
        window.center()
        self.window = window
        show(window)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }

    private func show(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
