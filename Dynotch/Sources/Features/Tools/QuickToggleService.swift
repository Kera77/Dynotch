import AppKit
import IOKit.pwr_mgt
import Observation

/// The quick toggles' state and actions (spec QT-1…QT-10).
@MainActor
@Observable
final class QuickToggleService {
    static let shared = QuickToggleService()

    private(set) var states: [QuickToggle: Bool] = [:]
    /// Keep Awake's end; nil while it runs without one (spec QT-3).
    private(set) var keepAwakeUntil: Date?
    private(set) var keepAwakeUntilTimerEnds = false
    /// A short line under a tile for a moment: "Click again to empty", "No disks" (spec QT-7, QT-11).
    private(set) var notes: [QuickToggle: String] = [:]

    @ObservationIgnored private var assertion: IOPMAssertionID?
    @ObservationIgnored private var expiry: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    var settings: ToolsSettings { .shared }

    func isOn(_ toggle: QuickToggle) -> Bool { states[toggle] ?? false }

    func start() {
        guard observers.isEmpty else { return }
        // Changes made elsewhere: the appearance and the default input (spec QT-1).
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { QuickToggleService.shared.refresh() } })
        refresh()
    }

    /// Reads every tile's state again; the Focus and the Finder off the main thread.
    func refresh() {
        states[.keepAwake] = assertion != nil
        states[.darkMode] = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        states[.nightShift] = NightShift.isOn
        Task {
            let read = await Task.detached { () -> [QuickToggle: Bool] in
                [
                    .muteMicrophone: Microphone.isMuted(),
                    .doNotDisturb: MacFocus.current() != nil,
                    .hideDock: DockSetting.hides
                ]
            }.value
            for (toggle, value) in read where states[toggle] != value { states[toggle] = value }
        }
    }

    /// A click on the tile, or its shortcut (spec QT-1, QT-4). Returns the new state.
    @discardableResult
    func toggle(_ toggle: QuickToggle) -> Bool {
        if toggle.isAction { return run(toggle) }
        let wanted = !isOn(toggle)
        switch toggle {
        case .keepAwake:
            if wanted { keepAwake(.indefinitely) } else { stopKeepingAwake() }
        case .doNotDisturb:
            ShortcutsApp.run(wanted ? settings.dndOnShortcut : settings.dndOffShortcut)
            states[.doNotDisturb] = wanted
        case .darkMode:
            setDarkMode(wanted)
        case .muteMicrophone:
            Microphone.setMuted(wanted)
            states[.muteMicrophone] = wanted
        case .nightShift:
            NightShift.set(wanted)
            states[.nightShift] = wanted
        case .hideDock:
            setDockHiding(wanted)
        case .lockScreen, .displaySleep, .emptyTrash, .ejectDisks:
            break
        }
        return wanted
    }

    /// The action tiles (spec QT-2, QT-7); true when it did something.
    private func run(_ toggle: QuickToggle) -> Bool {
        switch toggle {
        case .lockScreen:
            Task.detached { ScreenLock.lock() }
            return true
        case .displaySleep:
            Task.detached { _ = ProcessRunner.run("/usr/bin/pmset", ["displaysleepnow"], timeout: 5) }
            return true
        case .emptyTrash:
            return emptyTrash()
        case .ejectDisks:
            let count = Disks.ejectAll()
            if count == 0 { show("No disks", on: .ejectDisks, for: 2) }
            return count > 0
        default:
            return false
        }
    }

    /// Two clicks within 3 seconds: the first only asks (spec QT-7). True when it empties.
    private func emptyTrash() -> Bool {
        guard notes[.emptyTrash] == Self.clickAgain else {
            show(Self.clickAgain, on: .emptyTrash, for: 3)
            return false
        }
        notes[.emptyTrash] = nil
        Task {
            _ = await AppleScriptRunner.run(
                "tell application \"Finder\" to empty trash", log: "tools", what: "empty trash"
            ) { _ in true }
        }
        return true
    }

    static let clickAgain = "Click again to empty"

    private func show(_ note: String, on toggle: QuickToggle, for seconds: Double) {
        notes[toggle] = note
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            if self?.notes[toggle] == note { self?.notes[toggle] = nil }
        }
    }

    /// Do Not Disturb works only with its two Shortcuts chosen (spec QT-2).
    var needsSetup: (QuickToggle) -> Bool {
        { [settings] toggle in toggle == .doNotDisturb && (settings.dndOnShortcut.isEmpty || settings.dndOffShortcut.isEmpty) }
    }

    // MARK: - Keep Awake (spec QT-3)

    func keepAwake(_ length: KeepAwakeLength) {
        if assertion == nil {
            var created = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Wingmate Keep Awake" as CFString, &created
            )
            guard result == kIOReturnSuccess else { return }
            assertion = created
        }
        states[.keepAwake] = true
        keepAwakeUntilTimerEnds = length == .untilTimerEnds
        keepAwakeUntil = length.seconds.map { Date().addingTimeInterval($0) }
        expiry?.cancel()
        if let seconds = length.seconds {
            expiry = Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self?.stopKeepingAwake()
            }
        }
    }

    func stopKeepingAwake() {
        expiry?.cancel()
        if let assertion { IOPMAssertionRelease(assertion) }
        assertion = nil
        keepAwakeUntil = nil
        keepAwakeUntilTimerEnds = false
        states[.keepAwake] = false
    }

    /// A timer ended: "Until a timer ends" stops (spec QT-3).
    func timerEnded() {
        if keepAwakeUntilTimerEnds { stopKeepingAwake() }
    }

    // MARK: - Others

    private func setDarkMode(_ dark: Bool) {
        states[.darkMode] = dark
        let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(dark)"
        Task {
            _ = await AppleScriptRunner.run(script, log: "tools", what: "dark mode") { _ in true }
            refresh()
        }
    }

    /// System Events hides the Dock without restarting it (spec QT-7).
    private func setDockHiding(_ hides: Bool) {
        states[.hideDock] = hides
        let script = "tell application \"System Events\" to tell dock preferences to set autohide to \(hides)"
        Task {
            _ = await AppleScriptRunner.run(script, log: "tools", what: "dock hiding") { _ in true }
            refresh()
        }
    }
}
