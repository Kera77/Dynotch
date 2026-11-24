import Foundation

/// The Tools module's tabs (spec TM-1).
enum ToolsTab: String, CaseIterable, Identifiable, Codable, Sendable {
    case timer
    case stopwatch
    case pomodoro
    case toggles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: "Timer"
        case .stopwatch: "Stopwatch"
        case .pomodoro: "Pomodoro"
        case .toggles: "Toggles"
        }
    }

    var symbol: String {
        switch self {
        case .timer: "hourglass"
        case .stopwatch: "stopwatch"
        case .pomodoro: "circle.circle"
        case .toggles: "switch.2"
        }
    }
}

/// A countdown of the Timer tab (spec TM-7, TM-8). Running: it ends at `endDate`; paused: it
/// keeps what was left, so a restart or a sleep keeps it right (spec TM-6).
struct CountdownTimer: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var duration: TimeInterval
    var endDate: Date?
    var remainingWhenPaused: TimeInterval?

    init(name: String, duration: TimeInterval, now: Date) {
        id = UUID()
        self.name = name
        self.duration = duration
        endDate = now.addingTimeInterval(duration)
    }

    var isPaused: Bool { endDate == nil }

    func remaining(at now: Date) -> TimeInterval {
        if let endDate { return max(endDate.timeIntervalSince(now), 0) }
        return remainingWhenPaused ?? duration
    }

    /// The part still left, 1 at the start and 0 at the end.
    func fractionLeft(at now: Date) -> Double {
        duration > 0 ? min(max(remaining(at: now) / duration, 0), 1) : 0
    }

    var title: String { name.isEmpty ? "Timer" : name }

    mutating func pause(at now: Date) {
        guard endDate != nil else { return }
        remainingWhenPaused = remaining(at: now)
        endDate = nil
    }

    mutating func resume(at now: Date) {
        guard endDate == nil else { return }
        endDate = now.addingTimeInterval(remainingWhenPaused ?? duration)
        remainingWhenPaused = nil
    }

    /// +1 min (spec TM-8).
    mutating func addMinute() {
        duration += 60
        if let endDate {
            self.endDate = endDate.addingTimeInterval(60)
        } else {
            remainingWhenPaused = (remainingWhenPaused ?? 0) + 60
        }
    }
}

/// The stopwatch (spec TM-10, TM-11): what ran before the last start, and the laps' totals.
struct StopwatchState: Codable, Equatable, Sendable {
    var startedAt: Date?
    var accumulated: TimeInterval = 0
    /// The total time at each lap, oldest first.
    var lapTotals: [TimeInterval] = []

    var isRunning: Bool { startedAt != nil }
    var isReset: Bool { startedAt == nil && accumulated == 0 && lapTotals.isEmpty }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (startedAt.map { max(now.timeIntervalSince($0), 0) } ?? 0)
    }

    mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    mutating func pause(at now: Date) {
        guard startedAt != nil else { return }
        accumulated = elapsed(at: now)
        startedAt = nil
    }

    mutating func lap(at now: Date) {
        guard isRunning else { return }
        lapTotals.append(elapsed(at: now))
    }

    mutating func reset() {
        self = StopwatchState()
    }

    struct Lap: Equatable, Identifiable, Sendable {
        let number: Int
        let time: TimeInterval
        let total: TimeInterval
        var id: Int { number }
    }

    /// The laps, newest first (spec TM-11).
    var laps: [Lap] {
        var previous: TimeInterval = 0
        var result: [Lap] = []
        for (index, total) in lapTotals.enumerated() {
            result.append(Lap(number: index + 1, time: total - previous, total: total))
            previous = total
        }
        return result.reversed()
    }

    /// The fastest and the slowest lap's number, from 3 laps on (spec TM-11).
    nonisolated static func extremes(of laps: [Lap]) -> (fastest: Int, slowest: Int)? {
        guard laps.count >= 3,
              let fastest = laps.min(by: { $0.time < $1.time }),
              let slowest = laps.max(by: { $0.time < $1.time })
        else { return nil }
        return (fastest.number, slowest.number)
    }

    /// The laps as text for the clipboard (spec TM-11).
    nonisolated static func copyText(_ laps: [Lap]) -> String {
        laps.reversed().map { "Lap \($0.number)\t\(ClockText.text($0.time, tenths: true))\t\(ClockText.text($0.total, tenths: true))" }
            .joined(separator: "\n")
    }
}

/// Times as the notch writes them: "4:59", "1:04:59", with tenths "02:14.3" (spec TM-3, TM-10).
enum ClockText {
    nonisolated static func text(_ seconds: TimeInterval, tenths: Bool = false) -> String {
        let value = max(seconds, 0)
        if tenths {
            let whole = Int(value)
            let tenth = Int((value - Double(whole)) * 10)
            let hours = whole / 3600
            let minutes = (whole % 3600) / 60
            let secs = whole % 60
            if hours > 0 { return String(format: "%d:%02d:%02d.%d", hours, minutes, secs, tenth) }
            return String(format: "%02d:%02d.%d", minutes, secs, tenth)
        }
        // A countdown shows 0:01 until it really ends.
        let whole = Int(value.rounded(.up))
        let hours = whole / 3600
        let minutes = (whole % 3600) / 60
        let secs = whole % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// "5 min", "1 h 30 min", "45 s" for the presets and the notices.
    nonisolated static func duration(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded())
        if whole < 60 { return "\(whole) s" }
        let hours = whole / 3600
        let minutes = (whole % 3600) / 60
        let secs = whole % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) h") }
        if minutes > 0 { parts.append("\(minutes) min") }
        if secs > 0 { parts.append("\(secs) s") }
        return parts.joined(separator: " ")
    }
}

/// A typed duration (spec TM-7): `12` = 12 minutes, `1:30` = 1 min 30 s, `1:02:03`, `90s`,
/// `1h 15m`, `2h`. Nil for anything else, for zero, and for more than 24 hours.
enum DurationInput {
    nonisolated static func parse(_ text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty else { return nil }
        let seconds = trimmed.contains(":") ? clock(trimmed) : units(trimmed)
        guard let seconds, seconds > 0, seconds <= 24 * 3600 else { return nil }
        return seconds
    }

    private nonisolated static func clock(_ text: String) -> TimeInterval? {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false).map { Int($0) }
        guard (2...3).contains(parts.count), parts.allSatisfy({ $0 != nil }) else { return nil }
        let values = parts.compactMap { $0 }
        guard values.dropFirst().allSatisfy({ $0 < 60 }) else { return nil }
        return values.reduce(0) { TimeInterval($0) * 60 + TimeInterval($1) }
    }

    private nonisolated static func units(_ text: String) -> TimeInterval? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)?"#)
        else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        // Everything but spaces must belong to a number with its unit.
        let covered = matches.reduce(0) { $0 + $1.range.length }
        guard !matches.isEmpty, covered == text.replacingOccurrences(of: " ", with: "").count + spaces(inside: matches, of: text)
        else { return nil }
        var total: TimeInterval = 0
        for match in matches {
            guard let numberRange = Range(match.range(at: 1), in: text), let number = Double(text[numberRange]) else { return nil }
            let unit = Range(match.range(at: 2), in: text).map { String(text[$0]) } ?? "m"
            total += number * factor(unit)
        }
        return total
    }

    private nonisolated static func spaces(inside matches: [NSTextCheckingResult], of text: String) -> Int {
        matches.reduce(0) { count, match in
            guard let range = Range(match.range, in: text) else { return count }
            return count + text[range].filter { $0 == " " }.count
        }
    }

    private nonisolated static func factor(_ unit: String) -> TimeInterval {
        switch unit.first {
        case "h": 3600
        case "s": 1
        default: 60
        }
    }
}
