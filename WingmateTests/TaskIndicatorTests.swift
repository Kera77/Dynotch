import Foundation
import Testing
@testable import Wingmate

/// The tasks counter beside the notch (spec R-10, R-11).
@MainActor
struct TaskIndicatorTests {
    private func task(_ id: String, due: Date?, hasTime: Bool = false) -> ReminderItem {
        ReminderItem(id: id, title: id, listID: "l", due: due, dueHasTime: hasTime, priority: 0, isCompleted: false, created: nil)
    }

    private func task(_ id: String, list: String, due: Date?) -> ReminderItem {
        ReminderItem(id: id, title: id, listID: list, due: due, dueHasTime: true, priority: 0, isCompleted: false, created: nil)
    }

    @Test func todaysTasksFirstOtherwiseAllOpen() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10)))
        let yesterday = now.addingTimeInterval(-86_400)
        let nextWeek = now.addingTimeInterval(7 * 86_400)
        let today = [task("a", due: now), task("b", due: yesterday), task("c", due: nextWeek), task("d", due: nil)]
        #expect(TaskIndicatorLogic.count(today, now: now, calendar: calendar) == TaskCount(count: 2, isToday: true))
        let later = [task("c", due: nextWeek), task("d", due: nil)]
        #expect(TaskIndicatorLogic.count(later, now: now, calendar: calendar) == TaskCount(count: 2, isToday: false))
        #expect(TaskIndicatorLogic.count([], now: now, calendar: calendar) == nil)
    }

    @Test func hiddenCounterComesBackWhenTimeIsUpOrATaskArrives() {
        let now = Date()
        let until = now.addingTimeInterval(3600)
        #expect(!TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: ["a"], openIDs: ["a"], now: now))
        #expect(!TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: ["a", "b"], openIDs: ["a"], now: now))
        #expect(TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: ["a"], openIDs: ["a", "new"], now: now))
        #expect(TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: ["a"], openIDs: ["a"], now: until))
    }

    @Test func snoozeTimes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 22, minute: 30)))
        #expect(TaskSnooze.halfHour.until(from: now, calendar: calendar) == now.addingTimeInterval(1800))
        let tomorrow = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 19)))
        #expect(TaskSnooze.tomorrow.until(from: now, calendar: calendar) == tomorrow)
    }

    @Test func tasksSitAtTheFarRightWithoutAnIcon() {
        let items = IndicatorItem.items(meetings: [], usage: nil, tasks: TaskCount(count: 3, isToday: true))
        #expect(items.map(\.id) == ["tasks"])
        let layout = IndicatorLayout(items: items)
        #expect(layout.iconSlots.isEmpty)
        #expect(layout.leftWidth == 0)
        #expect(layout.rightWidth > 0)
    }

    @Test func tasksAreGroupedByListAndTheSoonestListComesFirst() {
        let now = Date()
        let lists = [
            ReminderList(id: "tasks", title: "Tasks", color: .fallback),
            ReminderList(id: "reminders", title: "Reminders", color: .fallback)
        ]
        let items = [
            task("a", list: "tasks", due: now.addingTimeInterval(2 * 86_400 + 7200)),
            task("b", list: "reminders", due: now.addingTimeInterval(2 * 86_400)),
            task("c", list: "tasks", due: nil)
        ]
        let groups = TaskIndicatorLogic.groups(items, lists: lists, now: now)
        #expect(groups.map(\.listID) == ["tasks", "reminders"])
        #expect(groups.first?.items.count == 2)
        #expect(TaskIndicatorLogic.defaultGroup(groups)?.listID == "reminders")
        let undated = TaskIndicatorLogic.groups(
            [task("x", list: "reminders", due: nil), task("y", list: "tasks", due: nil)], lists: lists, now: now
        )
        #expect(TaskIndicatorLogic.defaultGroup(undated)?.listID == "tasks")
    }

    @Test func everyListWithOpenTasksGetsACapsuleEvenIfOnlyOneHasTodays() {
        let now = Date()
        let lists = [
            ReminderList(id: "tasks", title: "Tasks", color: .fallback),
            ReminderList(id: "reminders", title: "Reminders", color: .fallback)
        ]
        let items = [
            task("today", list: "reminders", due: now.addingTimeInterval(-60)),
            task("later", list: "reminders", due: now.addingTimeInterval(5 * 86_400)),
            task("a", list: "tasks", due: nil),
            task("b", list: "tasks", due: now.addingTimeInterval(3 * 86_400))
        ]
        let groups = TaskIndicatorLogic.groups(items, lists: lists, now: now)
        #expect(groups.map(\.listID) == ["tasks", "reminders"])
        // Reminders has a task for today: only that one; Tasks has none: all of its open ones.
        #expect(groups.first { $0.listID == "reminders" }?.items.map(\.id) == ["today"])
        #expect(groups.first { $0.listID == "tasks" }?.items.count == 2)
        #expect(TaskIndicatorLogic.defaultGroup(groups)?.listID == "reminders")
    }
}

/// The tasks counter's drop-down list.
@MainActor
struct TaskDropDownTests {
    private func task(_ id: String, due: Date?) -> ReminderItem {
        ReminderItem(id: id, title: id, listID: "l", due: due, dueHasTime: true, priority: 0, isCompleted: false, created: nil)
    }

    @Test func dropDownListsTheCountedTasks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10)))
        let items = [task("later", due: now.addingTimeInterval(5 * 86_400)), task("noon", due: now.addingTimeInterval(7200)),
                     task("early", due: now.addingTimeInterval(-3600))]
        #expect(TaskIndicatorLogic.listed(items, now: now, calendar: calendar).map(\.id) == ["early", "noon"])
        let notToday = [task("b", due: nil), task("a", due: now.addingTimeInterval(3 * 86_400))]
        #expect(TaskIndicatorLogic.listed(notToday, now: now, calendar: calendar).map(\.id) == ["a", "b"])
    }

    @Test func dropDownHeightFollowsTheTasksUpToSix() {
        let base = IndicatorLayout.labelHeight
        #expect(IndicatorItem.tasks(TaskCount(count: 2, isToday: true)).labelHeight == base + 2 * 22 + 6)
        #expect(IndicatorItem.tasks(TaskCount(count: 20, isToday: false)).labelHeight == base + 6 * 22 + 6)
    }
}
