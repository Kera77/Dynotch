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
}
