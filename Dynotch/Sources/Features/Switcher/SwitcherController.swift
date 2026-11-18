import AppKit
import Carbon.HIToolbox
import Combine

/// The window switcher's state (spec AS-1…AS-11): opened by its shortcut or a swipe, it lists
/// the windows in the notch; the key again, the arrows or the fingers move the choice; letting
/// go switches (or, with Hold, a click or Return does); Escape cancels.
@MainActor
final class SwitcherController: ObservableObject {
    @Published private(set) var isShown = false
    @Published private(set) var items: [SwitcherItem] = []
    @Published private(set) var selection = 0
    /// Window previews by window id, filled in after opening (spec AS-7).
    @Published var previews: [CGWindowID: NSImage] = [:]

    let settings: SwitcherSettings
    /// Shows or hides the switcher in the notch.
    var present: (Bool) -> Void = { _ in }
    /// The display under the pointer, for "only this display" (spec AS-3).
    var displayFrame: () -> CGRect? = { nil }

    private static let signature: OSType = 0x4459_5357 // "DYSW"
    private var handler: EventHandlerRef?
    private var permanent: [EventHotKeyRef] = []
    private var temporary: [EventHotKeyRef] = []
    private var releaseTimer: Timer?
    private var heldModifiers: UInt32 = 0
    private var isHolding = false
    private var swipeStart = 0
    private var lastTravel = 0.0
    private var observer: AnyCancellable?
    private var registered: KeyShortcut?

    private enum Action: UInt32 {
        case open = 1, back, left, right, cancel, cancelPlain, close, minimize, quit, hide, confirm
    }

    init(settings: SwitcherSettings) {
        self.settings = settings
    }

    var selected: SwitcherItem? { items.indices.contains(selection) ? items[selection] : nil }

    func start() {
        installHandler()
        observer = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.registerShortcut() } }
        }
        registerShortcut()
    }

    // MARK: - Opening and moving

    /// Lists the windows and shows them; the second one is chosen, so one step goes back to the
    /// previous window (spec AS-2).
    func open() {
        guard settings.isOn, !isShown else { return }
        var options = SwitcherWindows.Options()
        options.scope = settings.scope
        options.groupsByApp = settings.groupsByApp
        options.showsMinimized = settings.showsMinimized
        options.showsHidden = settings.showsHidden
        options.display = settings.currentDisplayOnly ? displayFrame() : nil
        options.excluded = settings.excluded
        options.onlyCovered = settings.onlyCovered
        options.coverThreshold = settings.coverThreshold
        items = SwitcherWindows.list(options)
        guard !items.isEmpty else { return }
        // Covered windows only: the front one is not listed, so the first is the way back (spec AS-14).
        selection = items.count > 1 && !settings.onlyCovered ? 1 : 0
        previews = [:]
        isShown = true
        present(true)
        if settings.showsPreviews {
            let wanted = items
            Task { [weak self] in
                let captured = await SwitcherPreviews.capture(wanted)
                guard let self, self.isShown else { return }
                self.previews = captured
            }
        }
    }

    func move(by step: Int) {
        guard !items.isEmpty else { return }
        selection = (selection + step % items.count + items.count) % items.count
    }

    func choose(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selection = index
    }

    /// Switches to the chosen window, or only closes.
    func finish(switching: Bool) {
        guard isShown else { return }
        let chosen = selected
        isShown = false
        isHolding = false
        releaseTimer?.invalidate()
        releaseTimer = nil
        unregisterTemporary()
        present(false)
        if switching, let chosen {
            // After the notch has started to close.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { SwitcherWindows.activate(chosen) }
        }
    }

    /// A click on an entry switches to it (spec AS-10).
    func pick(_ index: Int) {
        choose(index)
        finish(switching: true)
    }

    // MARK: - Swipe (spec AS-11)

    func swipeBegan() {
        guard settings.isOn else { return }
        open()
        swipeStart = selection
    }

    /// `travel` in trackpad widths since the swipe began; one window per `settings.swipeStep`.
    /// Only the choice moves until the fingers lift, and it stops at either end (spec AS-11b).
    func swipeMoved(travel: Double) {
        guard isShown, !items.isEmpty else { return }
        lastTravel = travel
        let steps = Self.steps(travel: travel, step: settings.swipeStep)
        selection = min(max(swipeStart + steps, 0), items.count - 1)
    }

    nonisolated static func steps(travel: Double, step: Double) -> Int {
        let value = travel / max(step, 0.01)
        // 0.3 / 0.05 is 5.999…: a hair of tolerance keeps it 6.
        return Int((value + (value >= 0 ? 1e-9 : -1e-9)).rounded(.towardZero))
    }

    func swipeEnded(cancelled: Bool) {
        guard isShown else { return }
        DiagnosticsLog.append(
            "spaces", "switcher swipe: travel=\(String(format: "%.2f", lastTravel)) step=\(String(format: "%.2f", settings.swipeStep))"
        )
        finish(switching: !cancelled)
    }

    // MARK: - Keys (spec AS-8…AS-10)

    private func registerShortcut() {
        guard settings.shortcut != registered || (permanent.isEmpty && settings.shortcut != nil && settings.isOn) else { return }
        permanent.forEach { UnregisterEventHotKey($0) }
        permanent = []
        registered = settings.shortcut
        guard settings.isOn, let shortcut = settings.shortcut else { return }
        permanent += register(shortcut.keyCode, shortcut.modifiers, .open)
        permanent += register(shortcut.keyCode, shortcut.modifiers | UInt32(shiftKey), .back)
    }

    private func beginKeyboard() {
        heldModifiers = (settings.shortcut?.modifiers ?? 0) & UInt32(optionKey | cmdKey | controlKey)
        registerTemporary(modifiers: heldModifiers)
        let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkRelease() }
        }
        timer.tolerance = 0.006
        RunLoop.main.add(timer, forMode: .common)
        releaseTimer = timer
    }

    /// Letting go of the modifiers switches; with Hold the switcher stays for a click or Return.
    private func checkRelease() {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let held = flags.contains(.maskAlternate) || flags.contains(.maskCommand) || flags.contains(.maskControl)
        guard !held else { return }
        releaseTimer?.invalidate()
        releaseTimer = nil
        if settings.holdsAfterRelease {
            isHolding = true
            unregisterTemporary()
            registerTemporary(modifiers: 0)
        } else {
            finish(switching: true)
        }
    }

    private func fired(_ raw: UInt32) {
        guard let action = Action(rawValue: raw) else { return }
        switch action {
        case .open, .back:
            if isShown {
                move(by: action == .open ? 1 : -1)
            } else {
                open()
                if isShown {
                    if action == .back { selection = items.count - 1 }
                    beginKeyboard()
                }
            }
        case .left: move(by: -1)
        case .right: move(by: 1)
        case .cancel, .cancelPlain: finish(switching: false)
        case .confirm: finish(switching: true)
        case .close, .minimize, .quit, .hide: act(action)
        }
    }

    private func act(_ action: Action) {
        guard let item = selected else { return }
        switch action {
        case .close: SwitcherWindows.close(item)
        case .minimize: SwitcherWindows.minimize(item)
        case .quit: SwitcherWindows.quit(item)
        default: SwitcherWindows.hide(item)
        }
        items.removeAll { action == .quit || action == .hide ? $0.pid == item.pid : $0.id == item.id }
        if items.isEmpty { finish(switching: false) } else { selection = min(selection, items.count - 1) }
    }

    private func registerTemporary(modifiers: UInt32) {
        let keys: [(Int, Action)] = [
            (kVK_LeftArrow, .left), (kVK_RightArrow, .right), (kVK_UpArrow, .left), (kVK_DownArrow, .right),
            (kVK_Escape, .cancel), (kVK_ANSI_W, .close), (kVK_ANSI_M, .minimize), (kVK_ANSI_Q, .quit), (kVK_ANSI_H, .hide),
            (kVK_Return, .confirm)
        ]
        for (key, action) in keys { temporary += register(UInt32(key), modifiers, action) }
        if modifiers != 0 { temporary += register(UInt32(kVK_Escape), 0, .cancelPlain) }
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
            DiagnosticsLog.append("shortcuts", "switcher key \(action) not registered (\(status))")
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
            guard status == noErr, hotKey.signature == SwitcherController.signature else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<SwitcherController>.fromOpaque(userData).takeUnretainedValue()
            let raw = hotKey.id
            MainActor.assumeIsolated { controller.fired(raw) }
            return noErr
        }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
}
