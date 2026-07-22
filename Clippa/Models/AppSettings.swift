import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    var isMonitoringPaused: Bool {
        didSet { persist() }
    }
    var launchAtLogin: Bool {
        didSet { persist() }
    }
    var excludedBundleIdentifiers: [String] {
        didSet { persist() }
    }
    var hasShownAccessibilityOnboarding: Bool {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isMonitoringPaused = defaults.bool(forKey: Keys.isMonitoringPaused)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.excludedBundleIdentifiers = defaults.array(forKey: Keys.excludedBundleIdentifiers) as? [String] ?? PrivacyFilter.defaultExcludedBundleIdentifiers
        self.hasShownAccessibilityOnboarding = defaults.bool(forKey: Keys.hasShownAccessibilityOnboarding)
    }

    func addExcludedBundleIdentifier(_ identifier: String) {
        let cleaned = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !excludedBundleIdentifiers.contains(cleaned) else {
            return
        }
        excludedBundleIdentifiers.append(cleaned)
        excludedBundleIdentifiers.sort()
    }

    func removeExcludedBundleIdentifier(_ identifier: String) {
        excludedBundleIdentifiers.removeAll { $0 == identifier }
    }

    private func persist() {
        defaults.set(isMonitoringPaused, forKey: Keys.isMonitoringPaused)
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(excludedBundleIdentifiers, forKey: Keys.excludedBundleIdentifiers)
        defaults.set(hasShownAccessibilityOnboarding, forKey: Keys.hasShownAccessibilityOnboarding)
    }

    private enum Keys {
        static let isMonitoringPaused = "isMonitoringPaused"
        static let launchAtLogin = "launchAtLogin"
        static let excludedBundleIdentifiers = "excludedBundleIdentifiers"
        static let hasShownAccessibilityOnboarding = "hasShownAccessibilityOnboarding"
    }
}
