import CoreGraphics
import Foundation
import SQLite3
import Testing
@testable import Wingmate

/// Notifications: rules, the pop-up's text, snoozing, replies, tabs and the database (spec E-2c, E-17…E-20d).
@MainActor
struct NotificationsTests {
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

    @Test func everySystemNoticeBelongsToSystemSettings() {
        #expect(NotificationApp.isSystem(identifier: "com.apple.btmnotificationagent", hasApplication: false))
        #expect(NotificationApp.isSystem(identifier: "com.apple.somedaemon", hasApplication: false))
        #expect(NotificationApp.isSystem(identifier: "_system_center_:anything", hasApplication: false))
        #expect(NotificationApp.isSystem(identifier: NotificationApp.systemGroupID, hasApplication: false))
        // Apple's apps are apps; other vendors' identifiers are never system notices.
        #expect(!NotificationApp.isSystem(identifier: "com.apple.mail", hasApplication: true))
        #expect(!NotificationApp.isSystem(identifier: "com.vendor.tool", hasApplication: false))

        let name = "NotificationsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: defaults)
        let service = NotificationService(settings: settings)
        var daemon = NotificationApp(identifier: "com.apple.somedaemon", name: "System Settings", url: nil, icon: nil)
        daemon.isSystem = true
        #expect(service.isEnabled(daemon))
        settings.setNotificationApp(NotificationApp.systemGroupID, enabled: false)
        #expect(!service.isEnabled(daemon))
    }

    @Test func allowedDuringFocusIsNotTheDefaultRule() {
        var rule = NotificationRule()
        #expect(rule.isDefault)
        rule.popsUpDuringFocus = true
        #expect(!rule.isDefault)
    }

    @Test func snoozeTimes() {
        #expect(SnoozeChoice.hour.date(from: now, calendar: calendar) == now.addingTimeInterval(3600))
        #expect(SnoozeChoice.evening.date(from: now, calendar: calendar) == at(hour: 18))
        #expect(SnoozeChoice.tomorrow.date(from: now, calendar: calendar) == at(hour: 9, dayOffset: 1))
    }

    @Test func eveningAfterSixIsTheNextEvening() {
        let late = at(hour: 19)
        #expect(SnoozeChoice.evening.date(from: late, calendar: calendar) == at(hour: 18, dayOffset: 1))
    }

    @Test func linesCapThePopUpButNotTheCard() {
        let long = String(repeating: "Hosszú üzenet szövege, ami több sorba tördelődik. ", count: 12)
        let one = NotificationTextLayout.height(of: "Szia", width: 300, fontSize: 12, maxLines: 4)
        let capped = NotificationTextLayout.height(of: long, width: 300, fontSize: 12, maxLines: 4)
        let full = NotificationTextLayout.height(of: long, width: 300, fontSize: 12)
        #expect(abs(capped - 4 * one) < 1)
        #expect(full > capped)
    }

    @Test func popUpGrowsWithMessagesUpToItsLimit() {
        let short = NotificationTextLayout.peekHeight(texts: ["Szia"], notchHeight: 32, maxLines: 4)
        let two = NotificationTextLayout.peekHeight(texts: ["Szia", "Mizu?"], notchHeight: 32, maxLines: 4)
        let many = NotificationTextLayout.peekHeight(texts: Array(repeating: "Üzenet", count: 50), notchHeight: 32, maxLines: 4)
        #expect(two > short)
        #expect(many <= 32 + 24 + NotificationTextLayout.maxPeekTextHeight + 10)
    }

    @Test func hoveredCardStopsAtItsLimitAndScrolls() {
        let texts = Array(repeating: String(repeating: "szöveg ", count: 60), count: 10)
        #expect(NotificationTextLayout.stackHeight(texts: texts, notchHeight: 32) == NotificationTextLayout.maxStackHeight)
        #expect(NotificationTextLayout.stackHeight(texts: ["Szia"], notchHeight: 32) < 200)
    }

    @Test func oldRulesStillDecode() throws {
        let rule = try JSONDecoder().decode(NotificationRule.self, from: Data(#"{"hidesBanner":true}"#.utf8))
        #expect(rule.peekShowsMessage == nil)
        #expect(!rule.isDefault)
        #expect(NotificationRule(peekShowsMessage: true).isDefault == false)
    }

    @Test func recordUpdatedInPlaceIsFoundAgain() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("NotificationsTests-\(UUID().uuidString).db").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        var handle: OpaquePointer?
        #expect(sqlite3_open(path, &handle) == SQLITE_OK)
        let setup = """
        CREATE TABLE app (app_id INTEGER PRIMARY KEY, identifier TEXT);
        CREATE TABLE record (rec_id INTEGER PRIMARY KEY, app_id INTEGER, data BLOB, request_last_date REAL, delivered_date REAL);
        INSERT INTO app VALUES (1, 'app.zen-browser.zen');
        INSERT INTO record VALUES (5, 1, x'00', 100, 100);
        INSERT INTO record VALUES (6, 1, x'00', 110, 110);
        """
        #expect(sqlite3_exec(handle, setup, nil, nil, nil) == SQLITE_OK)

        let database = try NotificationDatabase(path: path)
        #expect(database.lastDelivered() == 110)
        #expect(try database.records(updatedAfter: 110, upTo: 6).isEmpty)
        // Zen replaces its notification for the same chat: record 5 is delivered again.
        #expect(sqlite3_exec(handle, "UPDATE record SET delivered_date = 120, request_last_date = 120 WHERE rec_id = 5", nil, nil, nil)
            == SQLITE_OK)
        #expect(try database.records(updatedAfter: 110, upTo: 6).map(\.id) == [5])
        #expect(database.lastDelivered() == 120)
        sqlite3_close(handle)
    }

    @Test func theCardSaysHowManyAreUnread() {
        #expect(NotificationService.unreadText(nil) == "1 unread message in Google Chat")
        #expect(NotificationService.unreadText(3) == "3 unread messages in Google Chat")
        #expect(NotificationService.unreadCount(in: "3 unread messages in Google Chat") == 3)
    }

    @Test func systemAlertOffKeepsMemoryOffAndSwapOn() throws {
        let defaults = try #require(UserDefaults(suiteName: "NotificationsTests.alerts"))
        defaults.removePersistentDomain(forName: "NotificationsTests.alerts")
        let split = NotificationPreferences.splitSystemAlert(["system"], defaults: defaults)
        #expect(split.contains("memory"))
        #expect(!split.contains("swap"))
        // Only once.
        #expect(NotificationPreferences.splitSystemAlert(["system"], defaults: defaults) == ["system"])
    }

    @Test func networkTabsFollowBeeperAndSurviveRelaunch() {
        let tabs = NotificationsTab.shown(mail: false, networks: ["WhatsApp"])
        #expect(tabs == [.all, .chats, .beeper, .network("WhatsApp"), .googleChat])
        #expect(NotificationsTab(rawValue: NotificationsTab.network("WhatsApp").rawValue) == .network("WhatsApp"))
        #expect(NotificationsTab(rawValue: "beeper") == .beeper)
        #expect(!NotificationsTab.network("WhatsApp").isWide)
    }

    @Test func emoticonsBecomeEmojiAsWords() {
        #expect(Emoticons.replace(in: "Hi :D ", includingLast: false) == "Hi 😄 ")
        // While typing, the last word waits for a space.
        #expect(Emoticons.replace(in: "Hi :D", includingLast: false) == "Hi :D")
        #expect(Emoticons.replace(in: "Hi :D", includingLast: true) == "Hi 😄")
        #expect(Emoticons.replace(in: ":) ok <3", includingLast: true) == "🙂 ok ❤️")
        // Links and times stay.
        #expect(Emoticons.replace(in: "https://x.com at 12:30 ", includingLast: true) == "https://x.com at 12:30 ")
    }

    @Test func hoverDropDownClosesOnlyWhenOpenedByHoverAndLeft() {
        var intent = HoverIntent(openedByHover: true, overButton: false, overPopover: false)
        #expect(intent.shouldClose)
        intent.overPopover = true
        #expect(!intent.shouldClose)
        intent = HoverIntent(openedByHover: false, overButton: false, overPopover: false)
        #expect(!intent.shouldClose)
    }
}
