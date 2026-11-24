import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// The calendar's day timeline and day strip (spec K-12).
struct CalendarTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        return calendar
    }

    /// 2026-11-18 10:00 Budapest
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10)) ?? Date()
    }

    private func at(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private func event(_ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: "\(start)", title: "E", start: start, end: end, isAllDay: allDay, color: .fallback, meetingURL: nil)
    }

    @Test func timelineSpansEightToEightByDefault() {
        #expect(TimelineRange.hours(for: [], on: now, calendar: calendar) == 8...20)
        let allDay = event(at(hour: 0), at(hour: 0, dayOffset: 1), allDay: true)
        #expect(TimelineRange.hours(for: [allDay], on: now, calendar: calendar) == 8...20)
    }

    @Test func timelineWidensForEarlyAndLateEvents() {
        let early = event(at(hour: 6, minute: 30), at(hour: 7))
        let late = event(at(hour: 21), at(hour: 22, minute: 15))
        #expect(TimelineRange.hours(for: [early, late], on: now, calendar: calendar) == 6...23)
    }

    @Test func timelinePositionIsClamped() {
        let hours = 8...20
        #expect(abs(TimelineRange.position(of: at(hour: 14), in: hours, on: now, calendar: calendar) - 0.5) < 0.0001)
        #expect(TimelineRange.position(of: at(hour: 5), in: hours, on: now, calendar: calendar) == 0)
        #expect(TimelineRange.position(of: at(hour: 23), in: hours, on: now, calendar: calendar) == 1)
    }

    @Test func dayStripSpansTwoWeeksEachWay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18)))
        let days = DayStripView.days(around: today, selected: today, calendar: calendar)
        #expect(days.count == 29)
        #expect(days.first == calendar.date(byAdding: .day, value: -14, to: today))
        #expect(days.last == calendar.date(byAdding: .day, value: 14, to: today))
        // A day further away (from the full calendar) is still shown.
        let far = try #require(calendar.date(byAdding: .day, value: 40, to: today))
        #expect(DayStripView.days(around: today, selected: far, calendar: calendar).contains(far))
    }

    @Test func calendarStopsAtTwoWeeks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18)))
        let far = try #require(calendar.date(byAdding: .day, value: 20, to: today))
        let near = try #require(calendar.date(byAdding: .day, value: -3, to: today))
        #expect(DayStripView.clamped(far, around: today, calendar: calendar) == calendar.date(byAdding: .day, value: 14, to: today))
        #expect(DayStripView.clamped(near, around: today, calendar: calendar) == near)
    }
}
