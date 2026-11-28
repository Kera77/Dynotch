import AppKit
import Observation
import SwiftUI

/// A macOS Focus as the Focus files describe it (spec FC-1).
struct FocusMode: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let symbol: String
    let tint: String?

    var color: Color { FocusMode.color(named: tint) }

    /// The system tint names of the Focus files ("systemIndigoColor"…).
    static func color(named name: String?) -> Color {
        let tint = name?.lowercased() ?? ""
        return tints.first { tint.contains($0.word) }?.color ?? .indigo
    }

    private static let tints: [(word: String, color: Color)] = [
        ("purple", .purple), ("blue", .blue), ("teal", .teal), ("cyan", .teal), ("green", .green), ("mint", .green),
        ("yellow", .yellow), ("orange", .orange), ("red", .red), ("pink", .pink), ("brown", .brown), ("gray", .gray), ("grey", .gray)
    ]

    /// Names for the built-in Focuses whose configuration has none.
    static func fallbackName(for id: String) -> String {
        let lower = id.lowercased()
        if lower.hasSuffix(".default") { return "Do Not Disturb" }
        if lower.contains("sleep") { return "Sleep" }
        if lower.contains("driving") { return "Driving" }
        if lower.contains("work") { return "Work" }
        if lower.contains("personal") { return "Personal" }
        if lower.contains("fitness") { return "Fitness" }
        if lower.contains("gaming") { return "Gaming" }
        if lower.contains("mindfulness") { return "Mindfulness" }
        if lower.contains("reading") { return "Reading" }
        return "Focus"
    }

    static func fallbackSymbol(for id: String) -> String {
        let lower = id.lowercased()
        if lower.contains("sleep") { return "bed.double.fill" }
        if lower.contains("driving") { return "car.fill" }
        if lower.contains("work") { return "briefcase.fill" }
        if lower.contains("personal") { return "person.fill" }
        if lower.contains("fitness") { return "figure.run" }
        if lower.contains("gaming") { return "gamecontroller.fill" }
        if lower.contains("mindfulness") { return "leaf.fill" }
        if lower.contains("reading") { return "book.fill" }
        return "moon.fill"
    }
}

/// How long a Focus chosen in the notch stays on (spec FC-2).
enum FocusLength: String, CaseIterable, Identifiable, Sendable {
    case hour, twoHours, tomorrowMorning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hour: "For 1 hour"
        case .twoHours: "For 2 hours"
        case .tomorrowMorning: "Until tomorrow morning"
        }
    }

    /// The morning hour, as in macOS's own "Until tomorrow morning".
    static let morningHour = 7

    /// When the Focus ends. Between midnight and 7:00 "tomorrow morning" is this morning.
    func end(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .hour: return now.addingTimeInterval(3600)
        case .twoHours: return now.addingTimeInterval(7200)
        case .tomorrowMorning:
            let today = calendar.date(bySettingHour: Self.morningHour, minute: 0, second: 0, of: now) ?? now
            return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
        }
    }
}

/// The Focus picker's state: the Focuses, the active one and its end, and the Shortcuts that
/// switch them (spec FC-1…FC-4). macOS lets no outside app switch a Focus, so turning on and
/// off goes through the owner's Shortcuts; the end is Wingmate's own timer.
@MainActor
@Observable
final class FocusModeService {
    static let shared = FocusModeService()

    struct Active: Equatable, Sendable {
        let mode: FocusMode
        /// Set when it was turned on from the notch with a length.
        let until: Date?
    }

    private enum Key {
        static let onShortcuts = "focusOnShortcuts"
        static let offShortcut = "focusOffShortcut"
        static let until = "focusUntil"
        static let untilMode = "focusUntilMode"
        static let shown = "focusButtonShown"
    }

    private(set) var modes: [FocusMode] = []
    private(set) var active: Active?

    /// The Shortcut that turns each Focus on, by its id.
    var onShortcuts: [String: String] {
        didSet { defaults.set(onShortcuts, forKey: Key.onShortcuts) }
    }

    /// The Shortcut that turns the Focus off.
    var offShortcut: String {
        didSet { defaults.set(offShortcut, forKey: Key.offShortcut) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var watcher: DispatchSourceFileSystemObject?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    @ObservationIgnored private var started = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onShortcuts = defaults.dictionary(forKey: Key.onShortcuts) as? [String: String] ?? [:]
        offShortcut = defaults.string(forKey: Key.offShortcut) ?? ""
    }

    func start() {
        guard !started else { return }
        started = true
        refresh()
        watchFolder()
        // The end of a length, and a fallback when the folder's events are missed.
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// The stored end of the Focus turned on from the notch.
    private var storedEnd: (mode: String, until: Date)? {
        guard let mode = defaults.string(forKey: Key.untilMode),
              let until = defaults.object(forKey: Key.until) as? Date
        else { return nil }
        return (mode, until)
    }

    private func storeEnd(_ end: (mode: String, until: Date)?) {
        defaults.set(end?.mode, forKey: Key.untilMode)
        defaults.set(end?.until, forKey: Key.until)
    }

    /// Reads the Focus files off the main thread, then ends an expired length (spec FC-3).
    func refresh() {
        Task {
            let snapshot = await Task.detached { FocusFiles.read() }.value
            apply(snapshot)
        }
    }

    func apply(_ snapshot: FocusFiles.Snapshot, now: Date = Date()) {
        if snapshot.modes != modes { modes = snapshot.modes }
        var end = storedEnd
        if let stored = end, stored.mode != snapshot.activeID {
            // Turned off or switched elsewhere: the length no longer applies.
            if snapshot.activeID != nil || now >= stored.until { storeEnd(nil) }
            end = nil
        }
        if let stored = end, now >= stored.until {
            DiagnosticsLog.append("focus", "length ended, turning off")
            storeEnd(nil)
            ShortcutsApp.run(offShortcut)
            setActive(nil)
            return
        }
        let next = snapshot.activeID.map { id in
            Active(mode: snapshot.modes.first { $0.id == id } ?? Self.mode(for: id), until: end?.until)
        }
        setActive(next)
    }

    private func setActive(_ next: Active?) {
        guard next != active else { return }
        withAnimation(Motion.quick) { active = next }
    }

    private static func mode(for id: String) -> FocusMode {
        FocusMode(id: id, name: FocusMode.fallbackName(for: id), symbol: FocusMode.fallbackSymbol(for: id), tint: nil)
    }

    // MARK: - Switching

    func canTurnOn(_ mode: FocusMode) -> Bool { !(onShortcuts[mode.id] ?? "").isEmpty }
    var canTurnOff: Bool { !offShortcut.isEmpty }

    /// Turns the Focus on until the length's end (spec FC-2).
    func turnOn(_ mode: FocusMode, for length: FocusLength, now: Date = Date()) {
        guard let shortcut = onShortcuts[mode.id], !shortcut.isEmpty else { return }
        ShortcutsApp.run(shortcut)
        noteLength(of: mode, until: length.end(from: now))
        DiagnosticsLog.append("focus", "on with a length (\(length.rawValue))")
        // The files change a moment later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.refresh() }
    }

    /// The Focus is on until then; Wingmate turns it off at that time (spec FC-3).
    func noteLength(of mode: FocusMode, until: Date) {
        storeEnd((mode.id, until))
        setActive(Active(mode: mode, until: until))
    }

    func turnOff() {
        storeEnd(nil)
        ShortcutsApp.run(offShortcut)
        setActive(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.refresh() }
    }

    /// "42 min left", "until 7:00", or nil without a length (spec FC-4).
    nonisolated static func remainingText(until: Date?, now: Date = Date()) -> String? {
        guard let until else { return nil }
        let left = until.timeIntervalSince(now)
        if left <= 0 { return nil }
        if left < 3600 { return "\(max(Int((left / 60).rounded(.up)), 1)) min left" }
        if left <= 2 * 3600 + 60 {
            let hours = Int(left / 3600)
            let minutes = Int(left.truncatingRemainder(dividingBy: 3600) / 60)
            return minutes == 0 ? "\(hours) h left" : "\(hours) h \(minutes) min left"
        }
        return "until " + until.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Watching the files

    private func watchFolder() {
        let path = FocusFiles.folder.path
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else {
            DiagnosticsLog.append("focus", "folder not readable: polling only")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .rename, .extend], queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher = source
    }
}

/// Reading the Focus files (needs Full Disk Access, like the notifications; spec E-20d).
enum FocusFiles {
    struct Snapshot: Equatable, Sendable {
        var modes: [FocusMode]
        var activeID: String?
    }

    nonisolated static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb/DB")
    }

    nonisolated static func read() -> Snapshot {
        let modes = (try? Data(contentsOf: folder.appendingPathComponent("ModeConfigurations.json")))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) }
            .map(modes(in:)) ?? []
        let active = (try? Data(contentsOf: folder.appendingPathComponent("Assertions.json")))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) }
            .flatMap(activeID(in:))
        return Snapshot(modes: modes, activeID: active)
    }

    /// Every configured Focus, Do Not Disturb first, then by name.
    nonisolated static func modes(in root: Any) -> [FocusMode] {
        guard let configurations = MacFocus.find("modeConfigurations", in: root) as? [String: Any] else { return [] }
        let found = configurations.compactMap { key, value -> FocusMode? in
            guard let configuration = value as? [String: Any] else { return nil }
            let mode = configuration["mode"] as? [String: Any] ?? [:]
            let id = mode["modeIdentifier"] as? String ?? key
            let name = (mode["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? FocusMode.fallbackName(for: id)
            let symbol = (mode["symbolImageName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? FocusMode.fallbackSymbol(for: id)
            return FocusMode(id: id, name: name, symbol: symbol, tint: mode["tintColorName"] as? String)
        }
        return found.sorted { lhs, rhs in
            let lhsDefault = lhs.id.hasSuffix(".default"), rhsDefault = rhs.id.hasSuffix(".default")
            if lhsDefault != rhsDefault { return lhsDefault }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// The active Focus's id; nil when none is on.
    nonisolated static func activeID(in root: Any) -> String? {
        guard let records = MacFocus.find("storeAssertionRecords", in: root) as? [[String: Any]], let first = records.first else {
            return nil
        }
        return MacFocus.find("assertionDetailsModeIdentifier", in: first) as? String ?? "com.apple.donotdisturb.mode.default"
    }
}
