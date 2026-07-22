import ApplicationServices
import Foundation

enum AccessibilityService {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
