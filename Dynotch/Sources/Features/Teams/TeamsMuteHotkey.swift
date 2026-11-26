import Carbon.HIToolbox
import Foundation

/// The global shortcut that mutes Teams, whichever app is in front (spec MT-7).
@MainActor
final class TeamsMuteHotkey {
    static let signature: OSType = 0x4459_544D // "DYTM"

    private let action: () -> Void
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func register(_ shortcut: KeyShortcut?) {
        installHandler()
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        guard let shortcut else { return }
        var registered: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &registered)
        if status == noErr {
            reference = registered
        } else {
            DiagnosticsLog.append("shortcuts", "Teams mute \(shortcut.display) not registered (\(status))")
        }
    }

    private func installHandler() {
        guard handler == nil else { return }
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKey = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &hotKey
            )
            guard status == noErr, hotKey.signature == TeamsMuteHotkey.signature else { return OSStatus(eventNotHandledErr) }
            let hotkey = Unmanaged<TeamsMuteHotkey>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { hotkey.action() }
            return noErr
        }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
}
