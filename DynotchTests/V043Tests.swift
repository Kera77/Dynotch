@testable import Dynotch
import Foundation
import Testing

/// The fixes and additions after 0.42.1: snooze, Focus, the day timeline, battery history,
/// due pills, the scratchpad and AI favorites.
struct V043Tests {
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

    // MARK: Snooze (E-19)

    @Test func snoozeTimes() {
        #expect(SnoozeChoice.hour.date(from: now, calendar: calendar) == now.addingTimeInterval(3600))
        #expect(SnoozeChoice.evening.date(from: now, calendar: calendar) == at(hour: 18))
        #expect(SnoozeChoice.tomorrow.date(from: now, calendar: calendar) == at(hour: 9, dayOffset: 1))
    }

    @Test func eveningAfterSixIsTheNextEvening() {
        let late = at(hour: 19)
        #expect(SnoozeChoice.evening.date(from: late, calendar: calendar) == at(hour: 18, dayOffset: 1))
    }

    // MARK: Day timeline (K-12)

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

    // MARK: Battery history (BT-6, BT-7)

    @Test func estimateFromTheDaysDischarge() throws {
        let samples = [
            BatterySample(date: now.addingTimeInterval(-10 * 3600), level: 80),
            BatterySample(date: now, level: 30)
        ]
        // 50 % in 10 hours: the remaining 30 % lasts 6 hours.
        let left = try #require(BatteryHistory.estimate(from: samples, now: now))
        #expect(abs(left - 6 * 3600) < 1)
        #expect(BatteryHistory.estimateText(left) == "about 6 hours left")
    }

    @Test func noEstimateWhileCharging() {
        let samples = [BatterySample(date: now.addingTimeInterval(-3600), level: 20), BatterySample(date: now, level: 40)]
        #expect(BatteryHistory.estimate(from: samples, now: now) == nil)
    }

    @MainActor @Test func historyKeepsAWeekOnDisk() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("battery-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let history = BatteryHistory(file: file)
        let mouse = BatteryDevice(id: "mouse", name: "Mouse", kind: .mouse, level: 50)
        history.record([mouse], at: now.addingTimeInterval(-8 * 86_400))
        history.record([mouse], at: now)
        #expect(history.samples["mouse"]?.count == 1)
        #expect(BatteryHistory(file: file).samples["mouse"]?.count == 1)
    }

    // MARK: Due pills (R-12)

    private func reminder(due: Date?, hasTime: Bool = true) -> ReminderItem {
        ReminderItem(id: "r", title: "R", listID: "l", due: due, dueHasTime: hasTime, priority: 0, isCompleted: false, created: nil)
    }

    @Test func dueUrgency() {
        #expect(ReminderLogic.urgency(of: reminder(due: nil), now: now, calendar: calendar) == nil)
        #expect(ReminderLogic.urgency(of: reminder(due: at(hour: 9)), now: now, calendar: calendar) == .overdue)
        #expect(ReminderLogic.urgency(of: reminder(due: at(hour: 15)), now: now, calendar: calendar) == .today)
        #expect(ReminderLogic.urgency(of: reminder(due: at(hour: 9, dayOffset: 1)), now: now, calendar: calendar) == .tomorrow)
        #expect(ReminderLogic.urgency(of: reminder(due: at(hour: 9, dayOffset: 4)), now: now, calendar: calendar) == .later)
    }

    // MARK: Scratchpad (J-12)

    @Test func scratchpadEscapesAndKeepsLines() {
        let html = NotesStore.appending("a < b & c\n\nnext", to: "<div>old</div>")
        #expect(html == "<div>old</div><div>a &lt; b &amp; c</div><div><br></div><div>next</div>")
    }

    // MARK: AI favorites (AI-15)

    @Test func favoritesNewestFirst() {
        var older = ChatMessage(role: .assistant, text: "old", date: now.addingTimeInterval(-60))
        older.isFavorite = true
        var newer = ChatMessage(role: .assistant, text: "new", date: now)
        newer.isFavorite = true
        let plain = ChatMessage(role: .assistant, text: "plain", date: now)
        let chat = ClaudeChat(title: "C", messages: [older, plain, newer])
        let favorites = ClaudeChatService.favorites(in: [chat])
        #expect(favorites.map(\.message.text) == ["new", "old"])
    }
}
