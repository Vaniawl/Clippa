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
