import Carbon.HIToolbox
import Foundation

@MainActor
@Observable
final class GlobalHotKeyService: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var onHotKey: (@MainActor () -> Void)?
    private(set) var registrationStatus: String = String(localized: "Not registered")

    func register(onHotKey: @escaping @MainActor () -> Void) {
        self.onHotKey = onHotKey
        unregister()

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard handlerStatus == noErr else {
            registrationStatus = String(localized: "Hotkey handler failed: \(handlerStatus)")
            return
        }

        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let modifiers = UInt32(cmdKey | shiftKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            registrationStatus = String(localized: "Registered")
        } else {
            registrationStatus = String(localized: "Shortcut is unavailable: \(status)")
            unregister()
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func fire() {
        onHotKey?()
    }

    private static let signature: OSType = 0x434C5050

    private static let eventHandler: EventHandlerUPP = { _, eventRef, userData in
        guard let eventRef, let userData else {
            return noErr
        }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr, hotKeyID.signature == GlobalHotKeyService.signature else {
            return noErr
        }
        let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userData).takeUnretainedValue()
        Task { @MainActor in
            service.fire()
        }
        return noErr
    }
}
