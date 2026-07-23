import AppKit
import Carbon.HIToolbox
import Foundation
import Observation

struct HotKeyShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultShowPanel = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey))

    var displayString: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }
        return result + keyDisplayName
    }

    var keyDisplayName: String {
        Self.keyDisplayName(for: keyCode) ?? "Key \(keyCode)"
    }

    func matches(_ event: NSEvent) -> Bool {
        keyCode == UInt32(event.keyCode) && modifiers == Self.carbonModifiers(from: event.modifierFlags)
    }

    static func from(event: NSEvent) -> HotKeyShortcut? {
        let modifiers = carbonModifiers(from: event.modifierFlags)
        let hasPrimaryModifier = modifiers & UInt32(cmdKey | controlKey | optionKey) != 0
        guard hasPrimaryModifier, keyDisplayName(for: UInt32(event.keyCode)) != nil else {
            return nil
        }
        return HotKeyShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        return modifiers
    }

    private static func keyDisplayName(for keyCode: UInt32) -> String? {
        keyNames[keyCode]
    }

    private static let keyNames: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A",
        UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E",
        UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G",
        UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K",
        UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M",
        UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q",
        UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S",
        UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W",
        UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y",
        UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0",
        UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4",
        UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6",
        UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_Space): "Space",
        UInt32(kVK_Tab): "Tab",
        UInt32(kVK_Return): "Return",
        UInt32(kVK_Escape): "Esc",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12"
    ]
}

@MainActor
@Observable
final class AppSettings {
    var excludedBundleIdentifiers: [String] {
        didSet { persist() }
    }
    var hasShownAccessibilityOnboarding: Bool {
        didSet { persist() }
    }
    var showPanelShortcut: HotKeyShortcut {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.excludedBundleIdentifiers = defaults.array(forKey: Keys.excludedBundleIdentifiers) as? [String] ?? PrivacyFilter.defaultExcludedBundleIdentifiers
        self.hasShownAccessibilityOnboarding = defaults.bool(forKey: Keys.hasShownAccessibilityOnboarding)
        self.showPanelShortcut = .defaultShowPanel
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
        defaults.set(excludedBundleIdentifiers, forKey: Keys.excludedBundleIdentifiers)
        defaults.set(hasShownAccessibilityOnboarding, forKey: Keys.hasShownAccessibilityOnboarding)
        defaults.set(try? encoder.encode(showPanelShortcut), forKey: Keys.showPanelShortcut)
    }

    private enum Keys {
        static let excludedBundleIdentifiers = "excludedBundleIdentifiers"
        static let hasShownAccessibilityOnboarding = "hasShownAccessibilityOnboarding"
        static let showPanelShortcut = "showPanelShortcut"
    }
}
