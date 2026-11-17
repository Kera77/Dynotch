import AppKit
import Carbon.HIToolbox
import Combine

/// The clipboard shortcuts (spec CB-2, CB-3). A quick press pastes the newest item; holding the
/// modifier shows the items in the notch, the arrows (or the key again) choose, letting go
/// pastes, Escape cancels. While choosing, the arrows, digits and Escape belong to Dynotch.
@MainActor
final class ClipboardPicker: ObservableObject {
    @Published private(set) var isShown = false
    @Published private(set) var tab = ClipboardTab.history
    @Published private(set) var selection = 0

    let store: ClipboardStore
    /// Shows or hides the items in the notch.
    var present: (Bool) -> Void = { _ in }

    private static let signature: OSType = 0x4459_4350 // "DYCP"
    private static let showDelay: TimeInterval = 0.25
    private var handler: EventHandlerRef?
    private var permanent: [EventHotKeyRef] = []
    private var temporary: [EventHotKeyRef] = []
    private var isActive = false
    private var startedAt = Date.distantPast
    private var releaseTimer: Timer?
    private var observer: AnyCancellable?

    private enum Action: UInt32 {
        case history = 1, saved, left, right, up, down, cancel, cancelPlain
        case digit1 = 11, digit2, digit3, digit4, digit5, digit6, digit7, digit8, digit9
    }

    init(store: ClipboardStore) {
        self.store = store
    }

    var items: [ClipItem] { store.items(in: tab) }

    func start() {
        installHandler()
        observer = store.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.registerPermanent() }
            }
        }
        registerPermanent()
    }

    // MARK: - Keys

    private var registeredShortcuts: [KeyShortcut?] = []

    private func registerPermanent() {
        let wanted = [store.historyShortcut, store.savedShortcut]
        guard wanted != registeredShortcuts else { return }
        registeredShortcuts = wanted
        permanent.forEach { UnregisterEventHotKey($0) }
        permanent = []
        if let shortcut = store.historyShortcut { permanent += register(shortcut.keyCode, shortcut.modifiers, .history) }
        if let shortcut = store.savedShortcut { permanent += register(shortcut.keyCode, shortcut.modifiers, .saved) }
    }

    private func registerTemporary(modifiers: UInt32) {
        var keys: [(Int, Action)] = [
            (kVK_LeftArrow, .left), (kVK_RightArrow, .right), (kVK_UpArrow, .up), (kVK_DownArrow, .down), (kVK_Escape, .cancel)
        ]
        let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        for (index, key) in digits.enumerated() {
            if let action = Action(rawValue: Action.digit1.rawValue + UInt32(index)) { keys.append((key, action)) }
        }
        for (key, action) in keys {
            temporary += register(UInt32(key), modifiers, action)
        }
        temporary += register(UInt32(kVK_Escape), 0, .cancelPlain)
    }

    private func unregisterTemporary() {
        temporary.forEach { UnregisterEventHotKey($0) }
        temporary = []
    }

    private func register(_ keyCode: UInt32, _ modifiers: UInt32, _ action: Action) -> [EventHotKeyRef] {
        var reference: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: action.rawValue)
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else {
            DiagnosticsLog.append("shortcuts", "clipboard key \(action) not registered (\(status))")
            return []
        }
        return [reference]
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
            // Other hot keys (the modules') belong to another handler.
            guard status == noErr, hotKey.signature == ClipboardPicker.signature else { return OSStatus(eventNotHandledErr) }
            let picker = Unmanaged<ClipboardPicker>.fromOpaque(userData).takeUnretainedValue()
            let raw = hotKey.id
            MainActor.assumeIsolated { picker.fired(raw) }
            return noErr
        }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    // MARK: - Choosing

    private func fired(_ raw: UInt32) {
        guard let action = Action(rawValue: raw) else { return }
        switch action {
        case .history, .saved:
            let wanted: ClipboardTab = action == .history ? .history : .saved
            if isActive, tab == wanted {
                move(by: 1)
                show()
            } else if isActive {
                tab = wanted
                selection = 0
            } else {
                begin(wanted)
            }
        case .left: move(by: -1)
        case .right: move(by: 1)
        case .up, .down:
            tab = tab == .history ? .saved : .history
            selection = 0
        case .cancel, .cancelPlain: finish(paste: false)
        default:
            let index = Int(raw - Action.digit1.rawValue)
            if items.indices.contains(index) { selection = index }
            show()
        }
    }

    private func begin(_ wanted: ClipboardTab) {
        isActive = true
        tab = wanted
        selection = 0
        startedAt = Date()
        let shortcut = wanted == .history ? store.historyShortcut : store.savedShortcut
        registerTemporary(modifiers: (shortcut?.modifiers ?? UInt32(optionKey)) & UInt32(optionKey | cmdKey | controlKey))
        let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkRelease() }
        }
        RunLoop.main.add(timer, forMode: .common)
        releaseTimer = timer
    }

    private func move(by step: Int) {
        guard !items.isEmpty else { return }
        selection = (selection + step + items.count) % items.count
    }

    private func show() {
        guard isActive, !isShown else { return }
        isShown = true
        present(true)
    }

    /// Letting go of the modifiers pastes; holding them past a moment shows the items.
    private func checkRelease() {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let held = flags.contains(.maskAlternate) || flags.contains(.maskCommand) || flags.contains(.maskControl)
        if held {
            if Date().timeIntervalSince(startedAt) >= Self.showDelay { show() }
        } else {
            finish(paste: true)
        }
    }

    private func finish(paste: Bool) {
        guard isActive else { return }
        isActive = false
        releaseTimer?.invalidate()
        releaseTimer = nil
        unregisterTemporary()
        let chosen = items.indices.contains(selection) ? items[selection] : nil
        if isShown {
            isShown = false
            present(false)
        }
        guard paste, let chosen else { return }
        // After the notch has started to close and the modifiers are up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.store.paste(chosen)
        }
    }
}
