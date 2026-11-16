@testable import Dynotch
import Foundation
import Testing

struct RemindersTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        return calendar
    }

    /// 2026-11-16 10:00 Budapest (Monday)
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10)) ?? Date()
    }

    private let lists = [
        ReminderList(id: "tasks", title: "Tasks", color: .fallback),
        ReminderList(id: "work", title: "Munka", color: .fallback)
    ]

    private func item(
        _ title: String, dueInDays: Int? = nil, hasTime: Bool = false, priority: Int = 0, list: String = "tasks"
    ) -> ReminderItem {
        let due = dueInDays.flatMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: now)) }
            .map { hasTime ? $0.addingTimeInterval(14 * 3600) : $0 }
        return ReminderItem(
            id: title, title: title, listID: list, due: due, dueHasTime: hasTime,
            priority: priority, isCompleted: false, created: nil
        )
    }

    @Test func sorting() {
        let items = [item("C", dueInDays: 3), item("A"), item("B", dueInDays: 1, priority: 1), item("D", priority: 5)]
        #expect(ReminderLogic.sorted(items, by: .due).map(\.title) == ["B", "C", "A", "D"])
        #expect(ReminderLogic.sorted(items, by: .priority).map(\.title) == ["B", "D", "A", "C"])
        #expect(ReminderLogic.sorted(items, by: .title).map(\.title) == ["A", "B", "C", "D"])
    }

    @Test func upcomingIncludesOverdueAndNextSevenDays() {
        let items = [item("overdue", dueInDays: -2), item("today", dueInDays: 0), item("week", dueInDays: 6),
                     item("later", dueInDays: 7), item("none")]
        #expect(ReminderLogic.upcoming(items, now: now, calendar: calendar).map(\.title) == ["overdue", "today", "week"])
    }

    @Test func overdueAndDueTexts() {
        let todayDateOnly = item("t", dueInDays: 0)
        #expect(!todayDateOnly.isOverdue(at: now, calendar: calendar))
        #expect(item("y", dueInDays: -1).isOverdue(at: now, calendar: calendar))
        #expect(ReminderLogic.dueText(for: todayDateOnly, now: now, calendar: calendar) == "ma")
        #expect(ReminderLogic.dueText(for: item("h", dueInDays: 1), now: now, calendar: calendar) == "holnap")
        #expect(ReminderLogic.dueText(for: item("y", dueInDays: -1), now: now, calendar: calendar) == "Lejárt · tegnap")
        #expect(ReminderLogic.dueText(for: item("n"), now: now, calendar: calendar) == nil)
    }

    @Test func parserReadsListAndDate() {
        // The date detector works in the machine's own time zone.
        let parsed = ReminderParser.parse("Meeting 2026-11-20 14:30 @munka", lists: lists, now: now, autoToday: false, removeDate: true)
        #expect(parsed.title == "Meeting")
        #expect(parsed.listID == "work")
        #expect(parsed.dueHasTime)
        #expect(parsed.due.map { Calendar.current.component(.hour, from: $0) } == 14)
    }

    @Test func parserKeepsDateWhenAskedAndNeverEmptiesTheTitle() {
        let kept = ReminderParser.parse("Call Anna on Friday", lists: lists, now: now, autoToday: false, removeDate: false)
        #expect(kept.title == "Call Anna on Friday")
        #expect(kept.due != nil)
        let removed = ReminderParser.parse("Call Anna on Friday", lists: lists, now: now, autoToday: false, removeDate: true)
        #expect(removed.title == "Call Anna")
        let lunch = ReminderParser.parse("Lunch tomorrow 1pm", lists: lists, now: now, autoToday: false, removeDate: true)
        #expect(!lunch.title.isEmpty)
    }

    @Test func parserAutoToday() {
        let plain = ReminderParser.parse(
            "Számla befizetése", lists: lists, now: now, autoToday: true, removeDate: true, calendar: calendar
        )
        #expect(plain.title == "Számla befizetése")
        #expect(plain.due == calendar.startOfDay(for: now))
        #expect(!plain.dueHasTime)
        #expect(ReminderParser.parse("Számla", lists: lists, now: now, autoToday: false, removeDate: true).due == nil)
    }

    @Test func unknownListMentionStaysInTheTitle() {
        let parsed = ReminderParser.parse("Írj @nincsilyen listára", lists: lists, now: now, autoToday: false, removeDate: true)
        #expect(parsed.listID == nil)
        #expect(parsed.title.contains("@nincsilyen"))
    }

    @Test @MainActor func openCountAndTasksFollowTheSelectedList() {
        let suite = "DynotchTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let store = RemindersStore(defaults: defaults)
        store.setLoadedState(
            lists: lists,
            open: [item("a"), item("b"), item("c", list: "work")],
            selectedListID: "tasks"
        )
        #expect(store.openCount == 2)
        #expect(store.tasks.map(\.title) == ["a", "b"])
        store.selectedListID = "work"
        #expect(store.openCount == 1)
    }
}

struct DayStepperTests {
    @Test func defaultNeedsALongerSwipe() {
        #expect(DayStepper().stepWidth >= 50)
    }

    @Test func stepsOneDayPerStepWidthFingersLeftGoForward() {
        var stepper = DayStepper()
        stepper.stepWidth = 26
        #expect(stepper.handle(phase: .began, isMomentum: false, fingerDeltaX: -10, deltaY: 0) == 0)
        #expect(stepper.handle(phase: .changed, isMomentum: false, fingerDeltaX: -20, deltaY: 0) == 1)
        #expect(stepper.handle(phase: .changed, isMomentum: false, fingerDeltaX: -60, deltaY: 0) == 2)
        // 12 pt left over forward; 30 pt back leaves -18, not yet a whole day.
        #expect(stepper.handle(phase: .changed, isMomentum: false, fingerDeltaX: 30, deltaY: 0) == 0)
        #expect(stepper.handle(phase: .changed, isMomentum: false, fingerDeltaX: 10, deltaY: 0) == -1)
    }

    @Test func momentumContinuesAndVerticalIsIgnored() {
        var stepper = DayStepper()
        stepper.stepWidth = 26
        _ = stepper.handle(phase: .began, isMomentum: false, fingerDeltaX: 0, deltaY: 30)
        #expect(stepper.handle(phase: .changed, isMomentum: false, fingerDeltaX: -10, deltaY: 40) == 0)
        #expect(!stepper.isHorizontal)

        var flick = DayStepper()
        flick.stepWidth = 26
        _ = flick.handle(phase: .began, isMomentum: false, fingerDeltaX: -5, deltaY: 0)
        #expect(flick.handle(phase: .none, isMomentum: true, fingerDeltaX: -60, deltaY: 0) == 2)
    }
}
