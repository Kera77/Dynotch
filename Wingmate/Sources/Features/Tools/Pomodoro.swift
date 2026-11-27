import Foundation

/// The pomodoro's phases (spec TM-14).
enum PomodoroPhase: String, Codable, Sendable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short break"
        case .longBreak: "Long break"
        }
    }

    var isBreak: Bool { self != .focus }
}

/// The lengths set in Settings › Tools › Pomodoro (spec TM-15).
struct PomodoroPlan: Equatable, Sendable {
    var focus: TimeInterval = 25 * 60
    var shortBreak: TimeInterval = 5 * 60
    var longBreak: TimeInterval = 15 * 60
    var longBreakAfter = 4

    func length(of phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .focus: focus
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
    }
}

/// Where the pomodoro stands (spec TM-14): the phase, the Focus phases done in this cycle, and
/// the end of the running phase (or what was left when paused), so it survives a restart (spec TM-6).
struct PomodoroState: Codable, Equatable, Sendable {
    var phase: PomodoroPhase = .focus
    var doneInCycle = 0
    var endDate: Date?
    var remainingWhenPaused: TimeInterval?

    var isRunning: Bool { endDate != nil }
    /// Not started yet, or reset.
    var isIdle: Bool { endDate == nil && remainingWhenPaused == nil }

    func remaining(at now: Date, plan: PomodoroPlan) -> TimeInterval {
        if let endDate { return max(endDate.timeIntervalSince(now), 0) }
        return remainingWhenPaused ?? plan.length(of: phase)
    }

    func fractionLeft(at now: Date, plan: PomodoroPlan) -> Double {
        let length = plan.length(of: phase)
        return length > 0 ? min(max(remaining(at: now, plan: plan) / length, 0), 1) : 0
    }

    mutating func start(at now: Date, plan: PomodoroPlan) {
        guard endDate == nil else { return }
        endDate = now.addingTimeInterval(remainingWhenPaused ?? plan.length(of: phase))
        remainingWhenPaused = nil
    }

    mutating func pause(at now: Date, plan: PomodoroPlan) {
        guard endDate != nil else { return }
        remainingWhenPaused = remaining(at: now, plan: plan)
        endDate = nil
    }

    mutating func reset() {
        self = PomodoroState()
    }

    /// The phase after `phase` ends or is skipped, and the Focus count of the cycle after it.
    nonisolated static func next(after phase: PomodoroPhase, doneInCycle: Int, plan: PomodoroPlan) -> (PomodoroPhase, Int) {
        switch phase {
        case .focus:
            let done = doneInCycle + 1
            return done >= max(plan.longBreakAfter, 1) ? (.longBreak, done) : (.shortBreak, done)
        case .shortBreak:
            return (.focus, doneInCycle)
        case .longBreak:
            return (.focus, 0)
        }
    }

    /// Moves to the next phase; it runs at once when `autoStart` says so, else it waits for Start.
    mutating func advance(at now: Date, plan: PomodoroPlan, autoStart: Bool) {
        let (nextPhase, done) = Self.next(after: phase, doneInCycle: doneInCycle, plan: plan)
        phase = nextPhase
        doneInCycle = done
        remainingWhenPaused = nil
        endDate = autoStart ? now.addingTimeInterval(plan.length(of: nextPhase)) : nil
    }
}

/// The finished Focus phases per day, for the count and the 7-day chart (spec TM-17).
struct PomodoroHistory: Codable, Equatable, Sendable {
    /// "2026-11-24" → count.
    var days: [String: Int] = [:]

    nonisolated static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    mutating func record(at date: Date) {
        days[Self.key(for: date), default: 0] += 1
        // Only the last few weeks are kept.
        if days.count > 60 {
            let oldest = days.keys.sorted().prefix(days.count - 60)
            oldest.forEach { days.removeValue(forKey: $0) }
        }
    }

    func count(on date: Date) -> Int {
        days[Self.key(for: date)] ?? 0
    }

    /// The last 7 days, oldest first, with today last.
    func lastWeek(endingAt now: Date, calendar: Calendar = .current) -> [(day: Date, done: Int)] {
        (0..<7).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: now).map { ($0, count(on: $0)) }
        }
    }
}
