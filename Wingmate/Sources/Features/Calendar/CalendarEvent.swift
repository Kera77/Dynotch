import Foundation

/// A calendar event, copied out of EventKit so it can be used freely in views and tests.
struct CalendarEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: CalendarColor
    let meetingURL: URL?

    func isOngoing(at now: Date) -> Bool {
        start <= now && now < end
    }

    func hasEnded(at now: Date) -> Bool {
        end <= now
    }
}

struct CalendarColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    static let fallback = CalendarColor(red: 0.35, green: 0.6, blue: 1)
}
