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

    var isEmpty: Bool { clock == nil && !micMuted && !awake }

    /// The tab its hover opens (spec TM-3, QT-5).
    var tab: ToolsTab { clock?.tab ?? .toggles }

    /// The soonest running countdown first, then a paused one, then the stopwatch (spec TM-4).
    nonisolated static func pick(countdowns: [Clock], stopwatch: Clock?) -> (Clock?, Int) {
        let running = countdowns.filter { $0.endDate != nil }.sorted { ($0.endDate ?? .distantFuture) < ($1.endDate ?? .distantFuture) }
        if let first = running.first { return (first, running.count - 1) }
        if let paused = countdowns.first { return (paused, countdowns.count - 1) }
        return (stopwatch, 0)
    }
}
