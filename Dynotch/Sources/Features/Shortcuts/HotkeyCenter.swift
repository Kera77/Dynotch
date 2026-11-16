import AppKit
import Carbon.HIToolbox
import Combine

/// Registers the features' shortcuts system-wide (spec SC-1). Carbon hot keys need no permission.
@MainActor
final class HotkeyCenter {
    private static let signature: OSType = 0x4459_4E43 // "DYNC"

    private let store: ShortcutStore
    private let onFire: (FeatureID) -> Void
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var observer: AnyCancellable?

    init(store: ShortcutStore, onFire: @escaping (FeatureID) -> Void) {
        self.store = store
        self.onFire = onFire
    }

    func start() {
        installHandler()
        observer = store.$shortcuts.sink { [weak self] shortcuts in
            MainActor.assumeIsolated { self?.register(shortcuts) }
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
            guard status == noErr else { return status }
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

    private func register(_ shortcuts: [FeatureID: KeyShortcut]) {
        references.forEach { UnregisterEventHotKey($0) }
        references = []
        for (index, feature) in FeatureID.allCases.enumerated() {
            guard let shortcut = shortcuts[feature] else { continue }
            var reference: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference {
                references.append(reference)
            } else {
                DiagnosticsLog.append("shortcuts", "\(feature.rawValue) \(shortcut.display) not registered (\(status))")
            }
        }
    }

    private func fired(_ number: Int) {
        let features = FeatureID.allCases
        guard features.indices.contains(number - 1) else { return }
        onFire(features[number - 1])
    }
}
