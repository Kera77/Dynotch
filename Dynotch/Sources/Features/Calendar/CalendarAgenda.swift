import Foundation

/// What the indicator beside the closed notch shows for an event.
struct EventStatus: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// Starts within the lead time.
        case upcoming
        /// Starts within `CalendarAgenda.imminentThreshold`.
        case imminent
        /// In progress.
        case ongoing
    }

    let phase: Phase
    /// Seconds until the start (upcoming, imminent) or until the end (ongoing).
    let remaining: TimeInterval
    /// 0…1: how much of the lead time, or of the meeting, has passed.
    let progress: Double
}

struct AgendaDay: Identifiable, Equatable, Sendable {
    let date: Date
    let events: [CalendarEvent]

    var id: Date { date }
}

/// Pure calendar logic: events per day, month grid and the upcoming event.
enum CalendarAgenda {
    /// The countdown turns red this long before the start.
    static let imminentThreshold: TimeInterval = 3 * 60
    /// Timed events at least this long (e.g. multi-day blocks) are not tracked by the indicator.
    static let longestTrackedEvent: TimeInterval = 24 * 3600
    /// Days listed in the full calendar's agenda, starting at the selected day.
    static let agendaDayCount = 14
    private static let gridCellCount = 42

    /// Events overlapping the given day: all-day events first, then by start time.
    static func events(on day: Date, from events: [CalendarEvent], calendar: Calendar = .current) -> [CalendarEvent] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return events
            .filter { $0.start < dayEnd && $0.end > dayStart }
            .sorted(by: sortOrder)
    }

    /// The selected day (even when empty) followed by the later days that have events.
    static func agenda(
        from events: [CalendarEvent],
        startingAt day: Date,
        dayCount: Int = agendaDayCount,
        calendar: Calendar = .current
    ) -> [AgendaDay] {
        let first = calendar.startOfDay(for: day)
        return (0..<dayCount).compactMap { offset -> AgendaDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            let dayEvents = Self.events(on: date, from: events, calendar: calendar)
            return offset == 0 || !dayEvents.isEmpty ? AgendaDay(date: date, events: dayEvents) : nil
        }
    }

    /// Number of events per day (keyed by start of day), for the dots under the dates.
    static func eventCounts(from events: [CalendarEvent], calendar: Calendar = .current) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for event in events {
            var day = calendar.startOfDay(for: event.start)
            var guardCount = 0
            while day < event.end, guardCount < 62 {
                counts[day, default: 0] += 1
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                guardCount += 1
            }
        }
        return counts
    }

    /// The 42 days (6 weeks) shown for a month, starting on the calendar's first weekday.
    static func monthGrid(for month: Date, calendar: Calendar = .current) -> [Date] {
        guard let firstOfMonth = calendar.dateInterval(of: .month, for: month)?.start else { return [] }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return (0..<gridCellCount).compactMap {
            calendar.date(byAdding: .day, value: $0 - leading, to: firstOfMonth)
        }
    }

    /// The event the day list scrolls to: the first timed one not over yet (in progress or
    /// next); none if every timed event has ended (spec K-5b).
    static func focusEvent(in events: [CalendarEvent], now: Date) -> CalendarEvent? {
        events.first { !$0.isAllDay && !$0.hasEnded(at: now) }
    }

    /// At most this many countdowns sit beside the closed notch.
    static let maxIndicatorEvents = 3

    /// The events shown beside the closed notch (spec K-7, K-8c): meetings in progress first,
    /// then timed events starting within `leadTime`, each group by start time.
    static func indicatorEvents(in events: [CalendarEvent], now: Date, leadTime: TimeInterval) -> [CalendarEvent] {
        let timed = events.filter {
            !$0.isAllDay && !$0.hasEnded(at: now) && $0.end.timeIntervalSince($0.start) < longestTrackedEvent
        }
        let ongoing = timed.filter { $0.isOngoing(at: now) }.sorted { $0.start < $1.start }
        let soon = timed
            .filter { $0.start > now && $0.start.timeIntervalSince(now) <= leadTime }
            .sorted { $0.start < $1.start }
        return Array((ongoing + soon).prefix(maxIndicatorEvents))
    }

    /// Phase, remaining time and fill of the indicator for an event (spec K-7…K-8).
    static func status(of event: CalendarEvent, now: Date, leadTime: TimeInterval) -> EventStatus {
        if now >= event.start {
            let duration = max(event.end.timeIntervalSince(event.start), 1)
            let elapsed = now.timeIntervalSince(event.start)
            return EventStatus(
                phase: .ongoing,
                remaining: max(0, event.end.timeIntervalSince(now)),
                progress: min(max(elapsed / duration, 0), 1)
            )
        }
        let remaining = event.start.timeIntervalSince(now)
        return EventStatus(
            phase: remaining <= imminentThreshold ? .imminent : .upcoming,
            remaining: remaining,
            progress: min(max(1 - remaining / max(leadTime, 1), 0), 1)
        )
    }

    /// "9:05" under an hour, otherwise whole minutes ("75p").
    static func countdownText(_ remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        if seconds >= 3600 { return "\(Int((Double(seconds) / 60).rounded(.up)))p" }
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    /// Short duration, e.g. "30 p", "1 ó", "1 ó 30 p".
    static func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int((duration / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) p" }
        return minutes == 0 ? "\(hours) ó" : "\(hours) ó \(minutes) p"
    }

    private static func sortOrder(_ lhs: CalendarEvent, _ rhs: CalendarEvent) -> Bool {
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        return lhs.title < rhs.title
    }
}
