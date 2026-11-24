import AppKit
import Carbon.HIToolbox

/// Registers the features' shortcuts system-wide (spec SC-1). Carbon hot keys need no permission.
@MainActor
final class HotkeyCenter {
    static let signature: OSType = 0x4459_4E43 // "DYNC"

    private let store: ShortcutStore
    private let onFire: (FeatureID) -> Void
    private let onPin: () -> Void
    private static let pinNumber = 100
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var observer: ChangeObservation?

    init(store: ShortcutStore, onFire: @escaping (FeatureID) -> Void, onPin: @escaping () -> Void) {
        self.store = store
        self.onFire = onFire
        self.onPin = onPin
    }

    func start() {
        installHandler()
        // Registers from the new state on the next run loop turn.
        observer = observeChanges { [store] in
            _ = store.shortcuts
            _ = store.pinShortcut
        } onChange: { [weak self] in
            self?.register()
        }
        register()
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
            guard status == noErr else { return status }
            // The clipboard's keys have a handler of their own (spec CB-2).
            guard hotKey.signature == HotkeyCenter.signature else { return OSStatus(eventNotHandledErr) }
            let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
            let number = Int(hotKey.id)
            MainActor.assumeIsolated { center.fired(number) }
            return noErr
        }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler
        )
    }

    private var registered: [Int: KeyShortcut] = [:]

    private func register() {
        var wanted: [Int: KeyShortcut] = [:]
        for (index, feature) in FeatureID.allCases.enumerated() {
            if let shortcut = store.shortcuts[feature] { wanted[index + 1] = shortcut }
        }
        if let pin = store.pinShortcut { wanted[Self.pinNumber] = pin }
        guard wanted != registered else { return }
        registered = wanted

        references.forEach { UnregisterEventHotKey($0) }
        references = []
        for (number, shortcut) in wanted {
            var reference: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(number))
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference {
                references.append(reference)
            } else {
                DiagnosticsLog.append("shortcuts", "#\(number) \(shortcut.display) not registered (\(status))")
            }
        }
    }

    private func fired(_ number: Int) {
        if number == Self.pinNumber {
            onPin()
            return
        }
        let features = FeatureID.allCases
        guard features.indices.contains(number - 1) else { return }
        onFire(features[number - 1])
    }
}
