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

    @Test func indicatorShowsOngoingAndUpcomingSideBySide() {
        let lead: TimeInterval = 10 * 60
        #expect(CalendarAgenda.indicatorEvents(in: [event("Far", startOffsetMinutes: 30)], now: now, leadTime: lead).isEmpty)

        let events = [
            event("Second soon", startOffsetMinutes: 9),
            event("Ongoing", startOffsetMinutes: -20, durationMinutes: 60),
            event("First soon", startOffsetMinutes: 4),
            event("Far", startOffsetMinutes: 30)
        ]
        let titles = CalendarAgenda.indicatorEvents(in: events, now: now, leadTime: lead).map(\.title)
        #expect(titles == ["Ongoing", "First soon", "Second soon"])
    }

    @Test func twoMeetingsAtTheSameTimeAreBothShown() {
        let events = [event("A", startOffsetMinutes: -5), event("B", startOffsetMinutes: -5, durationMinutes: 60)]
        #expect(CalendarAgenda.indicatorEvents(in: events, now: now, leadTime: 600).count == 2)
    }

    @Test func indicatorIsLimited() {
        let events = (1...5).map { event("M\($0)", startOffsetMinutes: Double($0)) }
        #expect(CalendarAgenda.indicatorEvents(in: events, now: now, leadTime: 600).count == CalendarAgenda.maxIndicatorEvents)
    }

    @Test func indicatorIgnoresAllDayEndedAndVeryLongEvents() {
        let events = [
            event("All day", startOffsetMinutes: -60, durationMinutes: 24 * 60, allDay: true),
            event("Ended", startOffsetMinutes: -60),
            event("Multi-day block", startOffsetMinutes: -60, durationMinutes: 3 * 24 * 60)
        ]
        #expect(CalendarAgenda.indicatorEvents(in: events, now: now, leadTime: 600).isEmpty)
    }

    @Test func statusBeforeStartFillsOverLeadTime() {
        let lead: TimeInterval = 10 * 60
        let upcoming = CalendarAgenda.status(of: event("Soon", startOffsetMinutes: 8), now: now, leadTime: lead)
        #expect(upcoming.phase == .upcoming)
        #expect(upcoming.remaining == 8 * 60)
        #expect(abs(upcoming.progress - 0.2) < 0.0001)

        let imminent = CalendarAgenda.status(of: event("Now-ish", startOffsetMinutes: 3), now: now, leadTime: lead)
        #expect(imminent.phase == .imminent)
        #expect(abs(imminent.progress - 0.7) < 0.0001)
    }

    @Test func statusDuringMeetingCountsDownToEnd() {
        let status = CalendarAgenda.status(
            of: event("Running", startOffsetMinutes: -15, durationMinutes: 60), now: now, leadTime: 600
        )
        #expect(status.phase == .ongoing)
        #expect(status.remaining == 45 * 60)
        #expect(abs(status.progress - 0.25) < 0.0001)
    }

    @Test func countdownText() {
        #expect(CalendarAgenda.countdownText(9 * 60 + 5) == "9:05")
        #expect(CalendarAgenda.countdownText(59.2) == "1:00")
        #expect(CalendarAgenda.countdownText(0) == "0:00")
        #expect(CalendarAgenda.countdownText(75 * 60) == "75m")
    }

    @Test func durationText() {
        #expect(CalendarAgenda.durationText(30 * 60) == "30m")
        #expect(CalendarAgenda.durationText(60 * 60) == "1h")
        #expect(CalendarAgenda.durationText(90 * 60) == "1h 30m")
    }

    /// Spec K-5b: the day list starts at the meeting in progress or the next one.
    @Test func focusEventIsTheFirstNotOver() {
        let events = [
            event("All day", startOffsetMinutes: -600, durationMinutes: 24 * 60, allDay: true),
            event("Morning", startOffsetMinutes: -120),
            event("Running", startOffsetMinutes: -10),
            event("Next", startOffsetMinutes: 60)
        ]
        #expect(CalendarAgenda.focusEvent(in: events, now: now)?.title == "Running")
        #expect(CalendarAgenda.focusEvent(in: Array(events.prefix(2)), now: now) == nil)
    }

    /// Spec K-8f: a meeting is announced once, when it enters the lead time.
    @Test func meetingsAreAnnouncedOnce() {
        let soon = event("Soon", startOffsetMinutes: 8)
        let running = event("Running", startOffsetMinutes: -5)
        let first = CalendarAgenda.newAnnouncement(in: [running, soon], announced: [], now: now)
        #expect(first.event?.title == "Soon")
        #expect(first.announced == ["Soon"])

        let again = CalendarAgenda.newAnnouncement(in: [running, soon], announced: first.announced, now: now)
        #expect(again.event == nil)

        // Ended meetings are forgotten, so the set stays small.
        let later = CalendarAgenda.newAnnouncement(in: [running], announced: first.announced, now: now)
        #expect(later.event == nil)
        #expect(later.announced.isEmpty)
    }
}
