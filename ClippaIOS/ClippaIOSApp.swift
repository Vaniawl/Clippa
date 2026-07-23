import SwiftUI

@main
struct ClippaIOSApp: App {
    @State private var store = IOSClipStore()

    var body: some Scene {
        WindowGroup {
            ClipsHomeView(store: store)
        }
    }
}
