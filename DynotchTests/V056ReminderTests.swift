@testable import Dynotch
import EventKit
import Foundation
import Testing

struct ReminderDetailsTests {
    private func item(_ title: String, created: TimeInterval?) -> ReminderItem {
        ReminderItem(
            id: title, title: title, listID: "l", due: nil, dueHasTime: false, priority: 0, isCompleted: false,
            created: created.map { Date(timeIntervalSince1970: $0) }
        )
    }

    @Test func theNewestReminderIsOnTop() {
        let items = [item("A", created: 100), item("B", created: 300), item("C", created: nil), item("D", created: 200)]
        #expect(ReminderLogic.sorted(items, by: .created).map(\.title) == ["B", "D", "A", "C"])
        #expect(ReminderSort.allCases.first == .created)
    }

    @Test func repeatRulesAreReadLikeTheRemindersApp() {
        #expect(ReminderRepeat.from(nil) == .never)
        for choice in ReminderRepeat.allCases where choice != .never && choice != .custom {
            #expect(ReminderRepeat.from(choice.rule.map { [$0] }) == choice)
        }
        let everyThreeDays = EKRecurrenceRule(recurrenceWith: .daily, interval: 3, end: nil)
        #expect(ReminderRepeat.from([everyThreeDays]) == .custom)
    }

    @Test func earlyAlertsAndPrioritiesMapToTheChoices() {
        #expect(EarlyReminder.from(offset: -900) == .fifteenMinutes)
        #expect(EarlyReminder.from(offset: -86_400) == .oneDay)
        #expect(ReminderDetails.normalizedPriority(3) == 1)
        #expect(ReminderDetails.normalizedPriority(5) == 5)
        #expect(ReminderDetails.normalizedPriority(7) == 9)
        #expect(ReminderDetails.normalizedPriority(0) == 0)
    }

    @Test func theDueDateKeepsATimeOnlyWhenAsked() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Budapest"))
        let due = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 13, minute: 0)))
        var details = ReminderDetails(
            title: "T", notes: "", url: "", hasDate: true, hasTime: true, due: due, repeats: .never, early: .none,
            listID: "l", priority: 0
        )
        #expect(details.dueComponents(calendar: calendar)?.hour == 13)
        details.hasTime = false
        #expect(details.dueComponents(calendar: calendar)?.hour == nil)
        #expect(details.dueComponents(calendar: calendar)?.day == 23)
        details.hasDate = false
        #expect(details.dueComponents(calendar: calendar) == nil)
    }

    @Test func columnsShowSmartListsOrAList() throws {
        for source in ReminderSource.smart + [.list("abc")] {
            #expect(ReminderSource(rawValue: source.rawValue) == source)
        }
        #expect(ReminderSource(rawValue: "nonsense") == nil)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func item(_ id: String, list: String, dueIn days: Double?) -> ReminderItem {
            ReminderItem(
                id: id, title: id, listID: list, due: days.map { now.addingTimeInterval($0 * 86_400) }, dueHasTime: true,
                priority: 0, isCompleted: false, created: nil
            )
        }
        let items = [item("a", list: "tasks", dueIn: nil), item("b", list: "reminders", dueIn: 0.01),
                     item("c", list: "reminders", dueIn: 20)]
        #expect(ReminderSource.all.filter(items, now: now).count == 3)
        #expect(ReminderSource.scheduled.filter(items, now: now).map(\.id) == ["b", "c"])
        #expect(ReminderSource.upcoming.filter(items, now: now).map(\.id) == ["b"])
        #expect(ReminderSource.list("tasks").filter(items, now: now).map(\.id) == ["a"])
    }
}
