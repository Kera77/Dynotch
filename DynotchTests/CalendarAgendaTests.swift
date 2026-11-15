@testable import Dynotch
import Foundation
import Testing

struct CalendarAgendaTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    /// 2026-11-14 10:00 Budapest
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 10)) ?? Date()
    }

    private func event(
        _ title: String,
        startOffsetMinutes: Double,
        durationMinutes: Double = 30,
        allDay: Bool = false
    ) -> CalendarEvent {
        let start = now.addingTimeInterval(startOffsetMinutes * 60)
        return CalendarEvent(
            id: title,
            title: title,
            start: start,
            end: start.addingTimeInterval(durationMinutes * 60),
            isAllDay: allDay,
            color: .fallback,
            meetingURL: nil
        )
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
    }

    @Test func eventsOnDayIncludeEndedOnesAndSortAllDayFirst() {
        let trip = CalendarEvent(
            id: "trip", title: "Trip",
            start: day(0), end: day(2),
            isAllDay: true, color: .fallback, meetingURL: nil
        )
        let events = [
            event("Later", startOffsetMinutes: 180),
            event("Ended", startOffsetMinutes: -120),
            trip,
            event("Tomorrow", startOffsetMinutes: 24 * 60)
        ]
        #expect(CalendarAgenda.events(on: now, from: events, calendar: calendar).map(\.title) == ["Trip", "Ended", "Later"])
        #expect(CalendarAgenda.events(on: day(1), from: events, calendar: calendar).map(\.title) == ["Trip", "Tomorrow"])
        #expect(CalendarAgenda.events(on: day(2), from: events, calendar: calendar).isEmpty)
        #expect(CalendarAgenda.events(on: day(-1), from: events, calendar: calendar).isEmpty)
    }

    @Test func agendaKeepsEmptyFirstDayAndSkipsLaterEmptyDays() {
        let events = [
            event("In 2 days", startOffsetMinutes: 2 * 24 * 60),
            event("In 20 days", startOffsetMinutes: 20 * 24 * 60)
        ]
        let agenda = CalendarAgenda.agenda(from: events, startingAt: now, calendar: calendar)
        #expect(agenda.map(\.date) == [day(0), day(2)])
        #expect(agenda[0].events.isEmpty)
        #expect(agenda[1].events.map(\.title) == ["In 2 days"])
    }

    @Test func eventCountsCoverEveryDayOfMultiDayEvents() {
        let trip = CalendarEvent(
            id: "trip", title: "Trip",
            start: day(0), end: day(2),
            isAllDay: true, color: .fallback, meetingURL: nil
        )
        let counts = CalendarAgenda.eventCounts(from: [trip, event("Call", startOffsetMinutes: 30)], calendar: calendar)
        #expect(counts[day(0)] == 2)
        #expect(counts[day(1)] == 1)
        #expect(counts[day(2)] == nil)
    }

    /// November 2026 starts on a Sunday; with Monday-first weeks the grid runs Oct 26 – Dec 6.
    @Test func monthGridStartsOnFirstWeekday() {
        let grid = CalendarAgenda.monthGrid(for: now, calendar: calendar)
        #expect(grid.count == 42)
        #expect(grid.first == calendar.date(from: DateComponents(year: 2026, month: 10, day: 26)))
        #expect(grid.last == calendar.date(from: DateComponents(year: 2026, month: 12, day: 6)))
        #expect(grid.contains(calendar.startOfDay(for: now)))
    }

    @Test func upcomingRespectsLeadTimeAndGracePeriod() {
        let lead: TimeInterval = 10 * 60
        #expect(CalendarAgenda.upcoming(in: [event("Far", startOffsetMinutes: 30)], now: now, leadTime: lead) == nil)
        #expect(CalendarAgenda.upcoming(in: [event("Soon", startOffsetMinutes: 8)], now: now, leadTime: lead)?.title == "Soon")
        #expect(CalendarAgenda.upcoming(in: [event("Just started", startOffsetMinutes: -3)], now: now, leadTime: lead)?
            .title == "Just started")
        #expect(CalendarAgenda.upcoming(in: [event("Started long ago", startOffsetMinutes: -6)], now: now, leadTime: lead) == nil)
    }

    @Test func upcomingIgnoresAllDayAndPicksEarliest() {
        let events = [
            event("All day", startOffsetMinutes: 5, allDay: true),
            event("Second", startOffsetMinutes: 9),
            event("First", startOffsetMinutes: 4)
        ]
        #expect(CalendarAgenda.upcoming(in: events, now: now, leadTime: 600)?.title == "First")
    }

    @Test func minutesUntilRoundsUp() {
        #expect(CalendarAgenda.minutesUntil(now.addingTimeInterval(61), now: now) == 2)
        #expect(CalendarAgenda.minutesUntil(now.addingTimeInterval(60), now: now) == 1)
        #expect(CalendarAgenda.minutesUntil(now.addingTimeInterval(-30), now: now) == 0)
    }

    @Test func durationText() {
        #expect(CalendarAgenda.durationText(30 * 60) == "30 p")
        #expect(CalendarAgenda.durationText(60 * 60) == "1 ó")
        #expect(CalendarAgenda.durationText(90 * 60) == "1 ó 30 p")
    }
}
