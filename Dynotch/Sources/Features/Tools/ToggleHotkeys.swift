import Carbon.HIToolbox
import Foundation

/// The quick toggles' global shortcuts (spec QT-4), with a handler of their own like the
/// clipboard's; a change by shortcut is announced in the HUD (spec HA-2).
@MainActor
final class ToggleHotkeys {
    static let signature: OSType = 0x4459_4E54 // "DYNT"

    private let settings: ToolsSettings
    private let announce: (QuickToggle, Bool) -> Void
    private var references: [EventHotKeyRef] = []
    private var registered: [QuickToggle: KeyShortcut] = [:]
    private var handler: EventHandlerRef?
    private var observer: ChangeObservation?

    init(settings: ToolsSettings, announce: @escaping (QuickToggle, Bool) -> Void) {
        self.settings = settings
        self.announce = announce
    }

    func start() {
        installHandler()
        observer = observeChanges { [settings] in
            _ = settings.toggleShortcuts
            _ = settings.togglesOn
            _ = settings.hiddenToggles
        } onChange: { [weak self] in
            self?.register()
        }
        register()
    }

    private func register() {
        // Only the tiles that are on (spec G-4).
        let wanted = settings.togglesOn
            ? settings.toggleShortcuts.filter { !settings.hiddenToggles.contains($0.key) && $0.key.isAvailable } : [:]
        guard wanted != registered else { return }
        registered = wanted
        references.forEach { UnregisterEventHotKey($0) }
        references = []
        for (toggle, shortcut) in wanted {
            guard let index = QuickToggle.allCases.firstIndex(of: toggle) else { continue }
            var reference: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference {
                references.append(reference)
            } else {
                DiagnosticsLog.append("shortcuts", "toggle \(toggle.rawValue) \(shortcut.display) not registered (\(status))")
            }
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
            guard status == noErr, hotKey.signature == ToggleHotkeys.signature else { return OSStatus(eventNotHandledErr) }
            let center = Unmanaged<ToggleHotkeys>.fromOpaque(userData).takeUnretainedValue()
            let number = Int(hotKey.id)
            MainActor.assumeIsolated { center.fired(number) }
            return noErr
        }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    private func fired(_ number: Int) {
        let toggles = QuickToggle.allCases
        guard toggles.indices.contains(number - 1) else { return }
        let toggle = toggles[number - 1]
        let isOn = QuickToggleService.shared.toggle(toggle)
        announce(toggle, isOn)
    }
}
