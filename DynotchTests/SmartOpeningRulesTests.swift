@testable import Dynotch
import Foundation
import Testing

@MainActor
/// The smart opening's code, download and morning rules (spec SO-5…SO-8).
struct SmartOpeningRulesTests {
    @Test func codesAreFourToEightDigits() {
        #expect(SmartOpening.code(in: "123456") == "123456")
        #expect(SmartOpening.code(in: " 123 456\n") == "123 456")
        #expect(SmartOpening.code(in: "123-456") == "123-456")
        #expect(SmartOpening.code(in: "123") == nil)
        #expect(SmartOpening.code(in: "123456789") == nil)
        #expect(SmartOpening.code(in: "12 34 56") == nil)
        #expect(SmartOpening.code(in: "12+34") == nil)
        #expect(SmartOpening.code(in: "AB1234") == nil)
    }

    @Test func aCodeIsNotACalculation() {
        #expect(SmartOpening.calculation(in: "123456") == nil)
        #expect(SmartOpening.calculation(in: "12*3") == "12*3")
    }

    @Test func morningIsFiveToNoon() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 0)) ?? Date()
        #expect(SmartOpening.morningKey(now: day.addingTimeInterval(4 * 3600), calendar: calendar) == nil)
        #expect(SmartOpening.morningKey(now: day.addingTimeInterval(7 * 3600), calendar: calendar) == "2026-11-19")
        #expect(SmartOpening.morningKey(now: day.addingTimeInterval(12 * 3600), calendar: calendar) == nil)
    }

    @Test func theNewRulesKeepTheirPlace() {
        var context = SmartContext(battery: "mouse")
        context.code = ("123456", 7)
        context.download = URL(fileURLWithPath: "/tmp/a.zip")
        context.morning = "2026-11-19"
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: [])?.feature == .clipboard)
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: ["code:7"])?.feature == .tray)
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: ["code:7", "download:/tmp/a.zip"])?.feature == .battery)
        let used: Set<String> = ["code:7", "download:/tmp/a.zip", "battery:mouse"]
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: used)?.feature == .calendar)
        #expect(SmartOpening.choose(context, isOn: { $0 != .morning }, used: used) == nil)
    }

    @Test func onlyFinishedRecentDownloadsCount() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let now = Date()
        let old = folder.appendingPathComponent("old.pdf")
        let partial = folder.appendingPathComponent("big.zip.crdownload")
        let fresh = folder.appendingPathComponent("fresh.zip")
        for url in [old, partial, fresh] { try Data("x".utf8).write(to: url) }
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-600)], ofItemAtPath: old.path)
        #expect(SmartOpening.recentDownload(now: now, folder: folder)?.lastPathComponent == "fresh.zip")
        try FileManager.default.removeItem(at: fresh)
        #expect(SmartOpening.recentDownload(now: now, folder: folder) == nil)
    }

    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func notice(_ feature: FeatureID, minutesAgo: Double = 1, tab: NotificationsTab? = nil) -> RecentNotice.Entry {
        RecentNotice.Entry(feature: feature, tab: tab, file: nil, id: "x", date: now.addingTimeInterval(-minutesAgo * 60))
    }

    @MainActor @Test func theFirstRuleThatAppliesWins() {
        var context = SmartContext()
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: []) == nil)
        context.usage = 95
        context.battery = "mouse"
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: [])?.feature == .battery)
        context.meeting = "m1"
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: [])?.feature == .calendar)
        // A rule turned off is skipped; an event used once is skipped too.
        #expect(SmartOpening.choose(context, isOn: { $0 != .meeting }, used: [])?.feature == .battery)
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: ["meeting:m1", "battery:mouse"])?.feature == .claudeUsage)
        context.usage = 80
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: ["meeting:m1", "battery:mouse"]) == nil)
    }

    @MainActor @Test func remindersDueSoonCount() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        func item(_ id: String, in minutes: Double?, hasTime: Bool = true) -> ReminderItem {
            ReminderItem(
                id: id, title: id, listID: "l", due: minutes.map { now.addingTimeInterval($0 * 60) }, dueHasTime: hasTime,
                priority: 0, isCompleted: false, created: nil
            )
        }
        #expect(SmartOpening.dueReminder(in: [item("later", in: 60), item("soon", in: 10)], now: now)?.id == "soon")
        #expect(SmartOpening.dueReminder(in: [item("overdue", in: -30)], now: now)?.id == "overdue")
        #expect(SmartOpening.dueReminder(in: [item("day", in: 5, hasTime: false), item("none", in: nil)], now: now) == nil)
    }

    @MainActor @Test func copiedCalculations() {
        #expect(SmartOpening.calculation(in: " 1200*1.27 \n") == "1200*1.27")
        #expect(SmartOpening.calculation(in: "42") == "42")
        #expect(SmartOpening.calculation(in: "hello world") == nil)
        #expect(SmartOpening.calculation(in: "1+1\n2+2") == nil)
    }

    @Test func latestNotificationLeadsEveryOpeningAfterTheMeeting() {
        var context = SmartContext(battery: "mouse")
        context.notice = notice(.notifications, tab: .beeper)
        // Not once: a used key does not stop it (SO-9).
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: ["notice:x"])?.feature == .notifications)
        context.meeting = "m1"
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: [])?.feature == .calendar)
        #expect(SmartOpening.choose(context, isOn: { $0 != .notice }, used: ["meeting:m1"])?.feature == .battery)
    }

    @Test func noticeWindowEnds() {
        #expect(SmartOpening.liveNotice(notice(.tray, minutesAgo: 4), now: now, window: 300)?.feature == .tray)
        #expect(SmartOpening.liveNotice(notice(.tray, minutesAgo: 6), now: now, window: 300) == nil)
        #expect(SmartOpening.liveNotice(nil, now: now, window: 300) == nil)
    }

    @Test func notificationTabBySource() {
        #expect(SmartOpening.tab(isBeeper: true, isGoogleChat: false) == .beeper)
        #expect(SmartOpening.tab(isBeeper: false, isGoogleChat: true) == .googleChat)
        #expect(SmartOpening.tab(isBeeper: false, isGoogleChat: false) == .all)
    }
}
