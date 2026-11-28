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
    nonisolated static func fallbackName(for id: String) -> String {
        let lower = id.lowercased()
        if lower.hasSuffix(".default") { return "Do Not Disturb" }
        if lower.contains("sleep") { return "Sleep" }
        if lower.contains("driving") { return "Driving" }
        if lower.contains("work") { return "Work" }
        if lower.contains("personal") { return "Personal" }
        if lower.contains("reduce-interruptions") { return "Reduce Interruptions" }
        if lower.contains("fitness") { return "Fitness" }
        if lower.contains("gaming") { return "Gaming" }
        if lower.contains("mindfulness") { return "Mindfulness" }
        if lower.contains("reading") { return "Reading" }
        return "Focus"
    }

    /// The Focus file's symbol when macOS draws it for apps; otherwise one by the id or name
    /// (some Focus files name Apple's own glyphs, which draw nothing in other apps; spec FC-1).
    nonisolated static func usableSymbol(_ name: String?, id: String, modeName: String) -> String {
        if let name, !name.isEmpty, NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil { return name }
        let byID = fallbackSymbol(for: id)
        return byID != "moon.fill" ? byID : fallbackSymbol(for: modeName)
    }

    nonisolated static func fallbackSymbol(for id: String) -> String {
        let lower = id.lowercased()
        if lower.contains("emoji") { return "face.smiling.inverse" }
        if lower.contains("reduce") { return "sparkles" }
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

/// How long a Focus chosen in the notch stays on: the lengths of macOS's Control Center (spec FC-2).
enum FocusLength: String, CaseIterable, Identifiable, Sendable {
    case hour, evening, event, untilOff

    var id: String { rawValue }

    /// The evening ends here, as Control Center's "Until this evening"; after it, "tomorrow morning".
    static let eveningHour = 19

    func title(now: Date = Date(), calendar: Calendar = .current) -> String {
        switch self {
        case .hour: "For 1 hour"
        case .evening: calendar.component(.hour, from: now) < Self.eveningHour ? "Until this evening" : "Until tomorrow morning"
        case .event: "Until the end of this event"
        case .untilOff: "Until I turn it off"
        }
    }

    /// Control Center's row for this length; `untilOff` has none (the Focus alone is pressed).
    func matches(_ label: String) -> Bool {
        switch self {
        case .hour: label == "For 1 hour"
        case .evening: label.hasPrefix("Until this evening") || label.hasPrefix("Until tomorrow morning")
        case .event: label.hasPrefix("Until the end of")
        case .untilOff: false
        }
    }

    /// The lengths offered now: the event's only during a calendar event.
    static func offered(duringEvent: Bool) -> [FocusLength] {
        duringEvent ? [.hour, .evening, .event, .untilOff] : [.hour, .evening, .untilOff]
    }

    /// A length row of Control Center, not a Focus.
    nonisolated static func isLengthLabel(_ label: String) -> Bool {
        label.hasPrefix("For ") || label.hasPrefix("Until ")
    }
}

/// The Focus picker's state: the Focuses as macOS lists them, the active one and its end
/// (spec FC-1…FC-4). Switching goes through Control Center (`ControlCenterFocus`); macOS ends a
/// length by itself.
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
        static let until = "focusUntil"
        static let untilMode = "focusUntilMode"
        static let macNames = "focusMacNames"
        static let macNamesSource = "focusMacNamesSource"
    }

    /// The Focuses in the picker: Control Center's list and order (spec FC-1).
    private(set) var modes: [FocusMode] = []
    private(set) var active: Active?
    /// A switch through Control Center is under way.
    private(set) var isSwitching = false

    @ObservationIgnored private var fileModes: [FocusMode] = []
    @ObservationIgnored private var activeID: String?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var watcher: DispatchSourceFileSystemObject?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?
    @ObservationIgnored private var started = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func start() {
        guard !started else { return }
        started = true
        refresh()
        watchFolder()
        // The time left, and a fallback when the folder's events are missed.
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

    /// Control Center's Focus names, as last read, and the Focus files' ids they were read for.
    private var macNames: [String] {
        get { defaults.stringArray(forKey: Key.macNames) ?? [] }
        set { defaults.set(newValue, forKey: Key.macNames) }
    }

    private var fileSignature: String { fileModes.map(\.id).sorted().joined(separator: ",") }

    /// Control Center's list is read again when the Focuses change in System Settings.
    var needsMacList: Bool {
        macNames.isEmpty || defaults.string(forKey: Key.macNamesSource) != fileSignature
    }

    /// Reads the Focus files off the main thread.
    func refresh() {
        Task {
            let snapshot = await Task.detached { FocusFiles.read() }.value
            apply(snapshot)
        }
    }

    func apply(_ snapshot: FocusFiles.Snapshot, now: Date = Date()) {
        if snapshot.modes != fileModes, !snapshot.modes.isEmpty {
            // Which symbols the Focus files name, to see why an icon is missing (no Focus names).
            DiagnosticsLog.append("focus", "symbols: " + snapshot.symbolNames.joined(separator: ", "))
        }
        fileModes = snapshot.modes
        activeID = snapshot.activeID
        rebuildModes()
        var end = storedEnd
        if let stored = end, stored.mode != snapshot.activeID || now >= stored.until {
            // Turned off, switched elsewhere or over: the length no longer applies.
            storeEnd(nil)
            end = nil
        }
        let next = snapshot.activeID.map { id in
            Active(mode: mode(for: id), until: end?.until)
        }
        setActive(next)
    }

    private func rebuildModes() {
        let names = macNames
        let next: [FocusMode]
        if names.isEmpty {
            next = fileModes
        } else {
            next = names.map { name in
                fileModes.first { $0.name == name }
                    ?? FocusMode(id: name, name: name, symbol: FocusMode.fallbackSymbol(for: name), tint: nil)
            }
        }
        if next != modes { modes = next }
    }

    private func mode(for id: String) -> FocusMode {
        fileModes.first { $0.id == id } ?? modes.first { $0.id == id }
            ?? FocusMode(id: id, name: FocusMode.fallbackName(for: id), symbol: FocusMode.fallbackSymbol(for: id), tint: nil)
    }

    private func setActive(_ next: Active?) {
        guard next != active else { return }
        withAnimation(Motion.quick) { active = next }
    }

    // MARK: - Switching

    /// Reads Control Center's Focus list when it is missing or out of date (spec FC-1).
    func loadMacListIfNeeded() async {
        guard needsMacList else { return }
        isSwitching = true
        defer { isSwitching = false }
        guard let names = await ControlCenterFocus.readNames(known: Set(fileModes.map(\.name))), !names.isEmpty else { return }
        noteMacNames(names)
    }

    private func noteMacNames(_ names: [String]) {
        guard !names.isEmpty else { return }
        macNames = names
        defaults.set(fileSignature, forKey: Key.macNamesSource)
        rebuildModes()
    }

    /// Turns the Focus on for the length, through Control Center (spec FC-2, FC-3).
    func turnOn(_ mode: FocusMode, for length: FocusLength, now: Date = Date()) {
        guard !isSwitching else { return }
        isSwitching = true
        DiagnosticsLog.append("focus", "on (\(length.rawValue))")
        let known = Set(fileModes.map(\.name))
        let accepts: ((String) -> Bool)? = length == .untilOff ? nil : { length.matches($0) }
        Task { @MainActor in
            let reading = await ControlCenterFocus.turnOn(mode.name, known: known, length: accepts)
            isSwitching = false
            guard let reading else { return }
            noteMacNames(reading.names)
            if let until = reading.header.flatMap({ Self.endTime(in: $0, now: now) }) {
                storeEnd((mode.id, until))
                setActive(Active(mode: mode, until: until))
            } else {
                storeEnd(nil)
                setActive(Active(mode: mode, until: nil))
            }
            // The files change a moment later.
            try? await Task.sleep(for: .seconds(1))
            refresh()
        }
    }

    func turnOff() {
        guard !isSwitching, let active else { return }
        isSwitching = true
        DiagnosticsLog.append("focus", "off")
        Task {
            let done = await ControlCenterFocus.turnOff(active.mode.name)
            isSwitching = false
            if done {
                storeEnd(nil)
                setActive(nil)
            }
            try? await Task.sleep(for: .seconds(1))
            refresh()
        }
    }

    /// The end in Control Center's header ("On Until 13:52", "On Until 7:00 PM"): the next such time.
    nonisolated static func endTime(in header: String, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let range = header.range(of: #"\d{1,2}[:.]\d{2}(\s?[AaPp][Mm])?"#, options: .regularExpression) else { return nil }
        let text = header[range].replacingOccurrences(of: ".", with: ":").uppercased()
        let digits = text.filter { $0.isNumber || $0 == ":" }.split(separator: ":").compactMap { Int($0) }
        guard digits.count == 2, digits[1] < 60 else { return nil }
        var hour = digits[0]
        if text.hasSuffix("PM"), hour < 12 { hour += 12 }
        if text.hasSuffix("AM"), hour == 12 { hour = 0 }
        guard hour < 24, let today = calendar.date(bySettingHour: hour, minute: digits[1], second: 0, of: now) else { return nil }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
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
