@testable import Dynotch
import Foundation
import Testing

/// Overdue tasks under the notch and the counter's colour (spec R-26, R-27).
struct OverdueTaskTests {
    private func task(_ id: String, due: Date?, hasTime: Bool = true) -> ReminderItem {
        ReminderItem(id: id, title: id, listID: "l", due: due, dueHasTime: hasTime, priority: 0, isCompleted: false, created: nil)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        return calendar
    }

    @Test func redWhenOverdueOrangeWithinTheHour() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 10)))
        let soon = task("soon", due: now.addingTimeInterval(1800))
        let late = task("late", due: now.addingTimeInterval(-60))
        let later = task("later", due: now.addingTimeInterval(7200))
        let dayOnly = task("day", due: calendar.startOfDay(for: now), hasTime: false)
        #expect(TaskIndicatorLogic.tone([soon, later], now: now, calendar: calendar) == .soon)
        #expect(TaskIndicatorLogic.tone([soon, late], now: now, calendar: calendar) == .overdue)
        #expect(TaskIndicatorLogic.tone([later, dayOnly], now: now, calendar: calendar) == .normal)
    }

    @Test func overdueStayUntilDismissedOrLater() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 10)))
        let old = task("old", due: now.addingTimeInterval(-7200))
        let new = task("new", due: now.addingTimeInterval(-60))
        let yesterday = task("day", due: calendar.startOfDay(for: now.addingTimeInterval(-86_400)), hasTime: false)
        let today = task("today", due: calendar.startOfDay(for: now), hasTime: false)
        let all = [new, today, old, yesterday]
        let shown = TaskIndicatorLogic.overdueNotices(all, now: now, dismissed: [:], later: [:], calendar: calendar)
        #expect(shown.map(\.id) == ["day", "old", "new"])
        let dismissed = ["old": try #require(old.due).timeIntervalSince1970]
        let laterOn = ["new": now.addingTimeInterval(600)]
        let hidden = TaskIndicatorLogic.overdueNotices(all, now: now, dismissed: dismissed, later: laterOn, calendar: calendar)
        #expect(hidden.map(\.id) == ["day"])
        // Later is up: back again; a new due date brings a dismissed task back.
        let back = TaskIndicatorLogic.overdueNotices(
            all, now: now, dismissed: ["old": 1], later: ["new": now.addingTimeInterval(-1)], calendar: calendar
        )
        #expect(back.map(\.id) == ["day", "old", "new"])
    }

    @Test func wakesAtTheNextChange() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 10)))
        let due = now.addingTimeInterval(7200)
        let next = TaskIndicatorLogic.nextChange([task("a", due: due)], now: now, later: [:], hiddenUntil: nil, calendar: calendar)
        #expect(next == due.addingTimeInterval(-3600))
        let sooner = TaskIndicatorLogic.nextChange(
            [task("a", due: due)], now: now, later: ["a": now.addingTimeInterval(60)], hiddenUntil: nil, calendar: calendar
        )
        #expect(sooner == now.addingTimeInterval(60))
    }

    @Test func thinRowsHeight() {
        // Always one row, however many are overdue (spec R-28).
        #expect(IndicatorLayout.overdueHeight == IndicatorLayout.overdueRowHeight + 6)
    }
}
