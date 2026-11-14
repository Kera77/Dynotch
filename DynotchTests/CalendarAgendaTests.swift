@testable import Dynotch
import Foundation
import Testing

struct CalendarAgendaTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
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
        allDay: Bool = false,
        meeting: Bool = false
    ) -> CalendarEvent {
        let start = now.addingTimeInterval(startOffsetMinutes * 60)
        return CalendarEvent(
            id: title,
            title: title,
            start: start,
            end: start.addingTimeInterval(durationMinutes * 60),
            isAllDay: allDay,
            color: .fallback,
            meetingURL: meeting ? URL(string: "https://zoom.us/j/1") : nil
        )
    }

    @Test func groupsIntoDaysAndDropsEndedEvents() {
        let events = [
            event("Ended", startOffsetMinutes: -120),
            event("Ongoing", startOffsetMinutes: -10),
            event("Later today", startOffsetMinutes: 180),
            event("Tomorrow", startOffsetMinutes: 24 * 60),
            event("In 8 days", startOffsetMinutes: 8 * 24 * 60),
        ]
        let days = CalendarAgenda.days(from: events, now: now, calendar: calendar)
        #expect(days.count == 2)
        #expect(days[0].events.map(\.title) == ["Ongoing", "Later today"])
        #expect(days[1].events.map(\.title) == ["Tomorrow"])
    }

    @Test func allDayEventsComeFirstAndSpanDays() {
        let todayStart = calendar.startOfDay(for: now)
        let trip = CalendarEvent(
            id: "trip", title: "Trip",
            start: todayStart,
            end: todayStart.addingTimeInterval(2 * 24 * 3600),
            isAllDay: true, color: .fallback, meetingURL: nil
        )
        let days = CalendarAgenda.days(from: [event("Call", startOffsetMinutes: 30), trip], now: now, calendar: calendar)
        #expect(days.count == 2)
        #expect(days[0].events.map(\.title) == ["Trip", "Call"])
        #expect(days[1].events.map(\.title) == ["Trip"])
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
            event("First", startOffsetMinutes: 4),
        ]
        #expect(CalendarAgenda.upcoming(in: events, now: now, leadTime: 600)?.title == "First")
    }

    @Test func minutesUntilRoundsUp() {
        #expect(CalendarAgenda.minutesUntil(now.addingTimeInterval(61), now: now) == 2)
        #expect(CalendarAgenda.minutesUntil(now.addingTimeInterval(60), now: now) == 1)
        #expect(CalendarAgenda.minutesUntil(now.addingTimeInterval(-30), now: now) == 0)
    }
}
