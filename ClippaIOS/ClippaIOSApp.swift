import AppIntents
import SwiftUI

@main
struct ClippaIOSApp: App {
    @State private var store: IOSClipStore

    init() {
        let store = IOSClipStore()
        if ProcessInfo.processInfo.arguments.contains("--seed-sample-clips") {
            store.replaceAll(IOSClip.sampleClips)
        }
        self._store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            ClipsHomeView(store: store)
        }
    }
}

struct SaveCurrentClipboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Current Clipboard"
    static let description = IntentDescription("Save the current iPhone clipboard into Clippa.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = IOSClipStore()
        let didSave = store.saveCurrentPasteboard()
        return .result(dialog: didSave ? "Saved to Clippa." : "Clipboard is empty.")
    }
}

struct OpenClippaIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Clippa"
    static let description = IntentDescription("Open Clippa to view saved clips.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct ClippaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveCurrentClipboardIntent(),
            phrases: [
                "Save clipboard to \(.applicationName)",
                "Add clipboard to \(.applicationName)"
            ],
            shortTitle: "Save Clipboard",
            systemImageName: "tray.and.arrow.down"
        )

        AppShortcut(
            intent: OpenClippaIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Show \(.applicationName)"
            ],
            shortTitle: "Open Clippa",
            systemImageName: "paperclip"
        )
    }
}
