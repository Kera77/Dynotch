import Foundation

struct AgendaDay: Identifiable, Equatable, Sendable {
    let date: Date
    let events: [CalendarEvent]

    var id: Date { date }
}

/// Pure calendar logic: events per day, month grid and the upcoming event.
enum CalendarAgenda {
    /// How long after its start an event still counts as "upcoming" (so you can join late).
    static let joinGracePeriod: TimeInterval = 5 * 60
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

    /// The timed event that starts within `leadTime`, or started less than `joinGracePeriod` ago.
    static func upcoming(in events: [CalendarEvent], now: Date, leadTime: TimeInterval) -> CalendarEvent? {
        events
            .filter { !$0.isAllDay }
            .filter { event in
                let untilStart = event.start.timeIntervalSince(now)
                return untilStart <= leadTime && untilStart > -joinGracePeriod && !event.hasEnded(at: now)
            }
            .min { $0.start < $1.start }
    }

    /// Whole minutes until `start`, rounded up; 0 once it has started.
    static func minutesUntil(_ start: Date, now: Date) -> Int {
        max(0, Int((start.timeIntervalSince(now) / 60).rounded(.up)))
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
