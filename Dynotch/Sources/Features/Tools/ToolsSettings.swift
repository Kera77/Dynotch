import Foundation
import Observation

/// The HUD announcements (spec HA-2), each with a switch (spec HA-3).
enum AnnouncementKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case charger
    case focus
    case capsLock
    case lowPower
    case toggleShortcut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .charger: "Charger connected or disconnected"
        case .focus: "Focus on or off"
        case .capsLock: "Caps Lock"
        case .lowPower: "Low Power Mode"
        case .toggleShortcut: "Quick toggle changed by its shortcut"
        }
    }

    /// Caps Lock starts off (spec HA-3).
    var isOnByDefault: Bool { self != .capsLock }
}

/// Settings › Tools (spec TM-2): the four tabs' switches and options and the HUD announcements.
@MainActor
@Observable
final class ToolsSettings {
    static let shared = ToolsSettings()

    @ObservationIgnored private let defaults: UserDefaults

    var timerOn: Bool { didSet { defaults.set(timerOn, forKey: "toolsTimerOn") } }
    var stopwatchOn: Bool { didSet { defaults.set(stopwatchOn, forKey: "toolsStopwatchOn") } }
    var pomodoroOn: Bool { didSet { defaults.set(pomodoroOn, forKey: "toolsPomodoroOn") } }
    var togglesOn: Bool { didSet { defaults.set(togglesOn, forKey: "toolsTogglesOn") } }
    var announcementsOn: Bool { didSet { defaults.set(announcementsOn, forKey: "toolsAnnouncementsOn") } }

    /// The tab picked last (spec TM-1).
    var tab: ToolsTab { didSet { defaults.set(tab.rawValue, forKey: "toolsTab") } }

    /// The preset minutes (spec TM-7), at most 8.
    var presets: [Int] { didSet { defaults.set(presets, forKey: "toolsTimerPresets") } }
    /// A system sound's name, or "" for none (spec TM-5).
    var sound: String { didSet { defaults.set(sound, forKey: "toolsSound") } }
    var stopwatchBesideNotch: Bool { didSet { defaults.set(stopwatchBesideNotch, forKey: "toolsStopwatchBeside") } }

    var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: "pomodoroFocus") } }
    var shortBreakMinutes: Int { didSet { defaults.set(shortBreakMinutes, forKey: "pomodoroShort") } }
    var longBreakMinutes: Int { didSet { defaults.set(longBreakMinutes, forKey: "pomodoroLong") } }
    var longBreakAfter: Int { didSet { defaults.set(longBreakAfter, forKey: "pomodoroLongAfter") } }
    var autoStartBreaks: Bool { didSet { defaults.set(autoStartBreaks, forKey: "pomodoroAutoBreaks") } }
    var autoStartFocus: Bool { didSet { defaults.set(autoStartFocus, forKey: "pomodoroAutoFocus") } }
    /// Shortcuts run when a Focus phase starts and ends (spec TM-16); "" for none.
    var focusStartShortcut: String { didSet { defaults.set(focusStartShortcut, forKey: "pomodoroStartShortcut") } }
    var focusEndShortcut: String { didSet { defaults.set(focusEndShortcut, forKey: "pomodoroEndShortcut") } }

    /// Do Not Disturb's two Shortcuts (spec QT-2).
    var dndOnShortcut: String { didSet { defaults.set(dndOnShortcut, forKey: "toggleDNDOn") } }
    var dndOffShortcut: String { didSet { defaults.set(dndOffShortcut, forKey: "toggleDNDOff") } }
    /// The tiles in their order, and the ones turned off (spec QT-4).
    var toggleOrder: [QuickToggle] { didSet { defaults.set(toggleOrder.map(\.rawValue), forKey: "toggleOrder") } }
    var hiddenToggles: Set<QuickToggle> { didSet { defaults.set(hiddenToggles.map(\.rawValue).sorted(), forKey: "toggleHidden") } }
    var toggleShortcuts: [QuickToggle: KeyShortcut] {
        didSet {
            let stored = Dictionary(uniqueKeysWithValues: toggleShortcuts.compactMap { key, value in
                (try? JSONEncoder().encode(value)).map { (key.rawValue, $0) }
            })
            defaults.set(stored, forKey: "toggleShortcuts")
        }
    }
    /// The muted microphone and Keep Awake beside the notch (spec QT-5).
    var micBesideNotch: Bool { didSet { defaults.set(micBesideNotch, forKey: "toggleMicBeside") } }
    var awakeBesideNotch: Bool { didSet { defaults.set(awakeBesideNotch, forKey: "toggleAwakeBeside") } }

    var announcements: [AnnouncementKind: Bool] {
        didSet {
            let stored = Dictionary(uniqueKeysWithValues: announcements.map { ($0.key.rawValue, $0.value) })
            defaults.set(stored, forKey: "hudAnnouncements")
        }
    }

    static let defaultPresets = [1, 3, 5, 10, 15, 30, 60]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func bool(_ key: String, _ value: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? value }
        func int(_ key: String, _ value: Int, _ range: ClosedRange<Int>) -> Int {
            min(max(defaults.object(forKey: key) as? Int ?? value, range.lowerBound), range.upperBound)
        }
        func text(_ key: String, _ value: String = "") -> String { defaults.string(forKey: key) ?? value }
        timerOn = bool("toolsTimerOn", true)
        stopwatchOn = bool("toolsStopwatchOn", true)
        pomodoroOn = bool("toolsPomodoroOn", true)
        togglesOn = bool("toolsTogglesOn", true)
        announcementsOn = bool("toolsAnnouncementsOn", true)
        tab = ToolsTab(rawValue: text("toolsTab")) ?? .timer
        let storedPresets = (defaults.array(forKey: "toolsTimerPresets") as? [Int])?.filter { (1...1440).contains($0) }
        presets = Array((storedPresets ?? Self.defaultPresets).prefix(8))
        sound = text("toolsSound", "Glass")
        stopwatchBesideNotch = bool("toolsStopwatchBeside", true)
        focusMinutes = int("pomodoroFocus", 25, 1...180)
        shortBreakMinutes = int("pomodoroShort", 5, 1...60)
        longBreakMinutes = int("pomodoroLong", 15, 1...120)
        longBreakAfter = int("pomodoroLongAfter", 4, 1...12)
        autoStartBreaks = bool("pomodoroAutoBreaks", true)
        autoStartFocus = bool("pomodoroAutoFocus", false)
        focusStartShortcut = text("pomodoroStartShortcut")
        focusEndShortcut = text("pomodoroEndShortcut")
        dndOnShortcut = text("toggleDNDOn")
        dndOffShortcut = text("toggleDNDOff")
        let order = (defaults.stringArray(forKey: "toggleOrder") ?? []).compactMap(QuickToggle.init(rawValue:))
        toggleOrder = order + QuickToggle.allCases.filter { !order.contains($0) }
        hiddenToggles = Set((defaults.stringArray(forKey: "toggleHidden") ?? []).compactMap(QuickToggle.init(rawValue:)))
        let storedShortcuts = defaults.dictionary(forKey: "toggleShortcuts") as? [String: Data] ?? [:]
        toggleShortcuts = Dictionary(uniqueKeysWithValues: storedShortcuts.compactMap { key, data in
            guard let toggle = QuickToggle(rawValue: key), let shortcut = try? JSONDecoder().decode(KeyShortcut.self, from: data)
            else { return nil }
            return (toggle, shortcut)
        })
        micBesideNotch = bool("toggleMicBeside", true)
        awakeBesideNotch = bool("toggleAwakeBeside", true)
        let storedAnnouncements = defaults.dictionary(forKey: "hudAnnouncements") as? [String: Bool] ?? [:]
        announcements = Dictionary(uniqueKeysWithValues: AnnouncementKind.allCases.map { kind in
            (kind, storedAnnouncements[kind.rawValue] ?? kind.isOnByDefault)
        })
    }

    var plan: PomodoroPlan {
        PomodoroPlan(
            focus: TimeInterval(focusMinutes * 60), shortBreak: TimeInterval(shortBreakMinutes * 60),
            longBreak: TimeInterval(longBreakMinutes * 60), longBreakAfter: longBreakAfter
        )
    }

    /// The module's tabs that are on, in order (spec TM-2).
    var shownTabs: [ToolsTab] {
        ToolsTab.allCases.filter(isOn)
    }

    func isOn(_ tab: ToolsTab) -> Bool {
        switch tab {
        case .timer: timerOn
        case .stopwatch: stopwatchOn
        case .pomodoro: pomodoroOn
        case .toggles: togglesOn
        }
    }

    func setOn(_ tab: ToolsTab, _ isOn: Bool) {
        switch tab {
        case .timer: timerOn = isOn
        case .stopwatch: stopwatchOn = isOn
        case .pomodoro: pomodoroOn = isOn
        case .toggles: togglesOn = isOn
        }
    }

    func announces(_ kind: AnnouncementKind) -> Bool {
        announcementsOn && announcements[kind] == true
    }

    /// The tiles shown, in order (spec QT-4).
    var shownToggles: [QuickToggle] {
        toggleOrder.filter { !hiddenToggles.contains($0) && $0.isAvailable }
    }

    /// Sets a toggle's shortcut; the same keys leave any other toggle (spec QT-4).
    func setShortcut(_ shortcut: KeyShortcut?, for toggle: QuickToggle) {
        var shortcuts = toggleShortcuts
        if let shortcut {
            for (other, existing) in shortcuts where other != toggle && existing.keyCode == shortcut.keyCode
                && existing.modifiers == shortcut.modifiers {
                shortcuts.removeValue(forKey: other)
            }
        }
        shortcuts[toggle] = shortcut
        toggleShortcuts = shortcuts
    }
}
