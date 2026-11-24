import AppKit
import IOKit.pwr_mgt
import Observation

/// The Toggles tab's state and actions (spec QT-1…QT-5).
@MainActor
@Observable
final class QuickToggleService {
    static let shared = QuickToggleService()

    private(set) var states: [QuickToggle: Bool] = [:]
    /// Keep Awake's end; nil while it runs without one (spec QT-3).
    private(set) var keepAwakeUntil: Date?
    private(set) var keepAwakeUntilTimerEnds = false

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
                    .hideDesktopIcons: FinderSetting.bool("CreateDesktop") == false,
                    .showHiddenFiles: FinderSetting.bool("AppleShowAllFiles") == true
                ]
            }.value
            for (toggle, value) in read where states[toggle] != value { states[toggle] = value }
        }
    }

    /// A click on the tile, or its shortcut (spec QT-1, QT-4). Returns the new state.
    @discardableResult
    func toggle(_ toggle: QuickToggle) -> Bool {
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
        case .hideDesktopIcons, .showHiddenFiles:
            setFinder(toggle, wanted)
        case .lockScreen:
            Task.detached { ScreenLock.lock() }
            return true
        }
        return wanted
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
                "Dynotch Keep Awake" as CFString, &created
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

    private func setFinder(_ toggle: QuickToggle, _ isOn: Bool) {
        states[toggle] = isOn
        let (key, value) = toggle == .hideDesktopIcons ? ("CreateDesktop", !isOn) : ("AppleShowAllFiles", isOn)
        Task.detached { FinderSetting.set(key, value) }
    }
}
