import Foundation
import ServiceManagement

enum LoginItemService {
    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            String(localized: "Enabled")
        case .requiresApproval:
            String(localized: "Requires approval")
        case .notFound:
            String(localized: "Unavailable")
        case .notRegistered:
            String(localized: "Disabled")
        @unknown default:
            String(localized: "Unknown")
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
