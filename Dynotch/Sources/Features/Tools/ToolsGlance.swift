import Foundation

/// What the Tools show beside the closed notch (spec TM-3, TM-4, QT-5): the soonest countdown
/// (or the stopwatch), how many more run, and the muted microphone and Keep Awake.
struct ToolsGlance: Equatable, Sendable {
    enum Tint: Equatable, Sendable {
        case white
        case red
        case green
    }

    /// A time beside the notch: counting down to `endDate`, up from `startedAt`, or standing at `fixed`.
    struct Clock: Equatable, Sendable {
        let tab: ToolsTab
        let symbol: String
        var endDate: Date?
        var startedAt: Date?
        /// Paused: what was left (countdown) or what ran (stopwatch).
        var fixed: TimeInterval = 0
        /// The countdown's length; 0 for the stopwatch.
        var total: TimeInterval = 0
        var tint: Tint = .white
        /// The timer its hover controls act on (spec TM-20).
        var timerID: UUID?
        /// "Tea", "Focus", "Stopwatch": written in the hover controls (spec TM-19).
        var title = ""

        var isCountdown: Bool { total > 0 }
        var isPaused: Bool { endDate == nil && startedAt == nil }

        func seconds(at now: Date) -> TimeInterval {
            if let endDate { return max(endDate.timeIntervalSince(now), 0) }
            if let startedAt { return fixed + max(now.timeIntervalSince(startedAt), 0) }
            return fixed
        }

        /// The part left of a countdown; nil for the stopwatch.
        func fractionLeft(at now: Date) -> Double? {
            guard isCountdown else { return nil }
            return min(max(seconds(at: now) / total, 0), 1)
        }

        /// Ends within a minute: it stands before the other indicators (spec TM-4).
        func endsSoon(at now: Date) -> Bool {
            guard let endDate else { return false }
            return endDate.timeIntervalSince(now) <= 60
        }
    }

    var clock: Clock?
    /// More countdowns running besides the one shown (spec TM-4).
    var more = 0
    var micMuted = false
    var awake = false
    /// Beside the notch (or in Wings) the hovered glance widens with its controls (spec TM-19).
    var unfolded = false

    var isEmpty: Bool { clock == nil && !micMuted && !awake }

    /// The buttons its hover shows (spec TM-20).
    var controls: [ToolsControl] {
        guard let clock else {
            return (micMuted ? [ToolsControl.unmute] : []) + (awake ? [ToolsControl.endAwake] : [])
        }
        switch clock.tab {
        case .timer: return [clock.isPaused ? .resume : .pause, .addMinute, .cancel]
        case .stopwatch: return clock.isPaused ? [.start, .reset] : [.pause, .lap, .reset]
        case .pomodoro: return [clock.isPaused ? .start : .pause, .next, .reset]
        }
    }

    /// The tab its hover opens (spec TM-3); nil: the quick toggles (spec QT-9).
    var tab: ToolsTab? { clock?.tab }

    /// The soonest running countdown first, then a paused one, then the stopwatch (spec TM-4).
    nonisolated static func pick(countdowns: [Clock], stopwatch: Clock?) -> (Clock?, Int) {
        let running = countdowns.filter { $0.endDate != nil }.sorted { ($0.endDate ?? .distantFuture) < ($1.endDate ?? .distantFuture) }
        if let first = running.first { return (first, running.count - 1) }
        if let paused = countdowns.first { return (paused, countdowns.count - 1) }
        return (stopwatch, 0)
    }
}

/// A button of the hover controls on the Tools indicator (spec TM-20).
enum ToolsControl: String, Identifiable, Sendable {
    case pause, resume, start, addMinute, cancel, lap, reset, next, unmute, endAwake

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .pause: "pause.fill"
        case .resume, .start: "play.fill"
        case .addMinute: "goforward.60"
        case .cancel: "xmark"
        case .lap: "flag.fill"
        case .reset: "arrow.counterclockwise"
        case .next: "forward.end.fill"
        case .unmute: "mic.fill"
        case .endAwake: "cup.and.saucer.fill"
        }
    }

    var help: String {
        switch self {
        case .pause: "Pause"
        case .resume: "Resume"
        case .start: "Start"
        case .addMinute: "+1 min"
        case .cancel: "Cancel"
        case .lap: "Lap"
        case .reset: "Reset"
        case .next: "Next phase"
        case .unmute: "Unmute the microphone"
        case .endAwake: "Stop keeping awake"
        }
    }
}
