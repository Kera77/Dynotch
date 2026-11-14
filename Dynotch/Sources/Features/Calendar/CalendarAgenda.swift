import Foundation

struct AgendaDay: Identifiable, Equatable, Sendable {
    let date: Date
    let events: [CalendarEvent]

    var id: Date { date }
}

/// Pure calendar logic: grouping into days and picking the upcoming event.
enum CalendarAgenda {
    static let dayCount = 7
    /// How long after its start an event still counts as "upcoming" (so you can join late).
    static let joinGracePeriod: TimeInterval = 5 * 60

    /// Groups events into `dayCount` days starting today. An event appears on every day it overlaps.
    /// Events that already ended are left out; empty days are dropped.
    static func days(
        from events: [CalendarEvent],
        now: Date,
        dayCount: Int = dayCount,
        calendar: Calendar = .current
    ) -> [AgendaDay] {
        let today = calendar.startOfDay(for: now)
        return (0..<dayCount).compactMap { offset -> AgendaDay? in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: today),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            else { return nil }

            let dayEvents = events
                .filter { $0.start < dayEnd && $0.end > dayStart && !$0.hasEnded(at: now) }
                .sorted(by: sortOrder)
            return dayEvents.isEmpty ? nil : AgendaDay(date: dayStart, events: dayEvents)
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

    private static func sortOrder(_ lhs: CalendarEvent, _ rhs: CalendarEvent) -> Bool {
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
        if lhs.start != rhs.start { return lhs.start < rhs.start }
        return lhs.title < rhs.title
    }
}
