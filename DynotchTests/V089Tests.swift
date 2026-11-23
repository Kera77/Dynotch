@testable import Dynotch
import Foundation
import Testing

/// Tasks by list, the default browser only, highlighted Beeper networks, the iPad's link item.
@MainActor
struct V089Tests {
    private func task(_ id: String, list: String, due: Date?) -> ReminderItem {
        ReminderItem(id: id, title: id, listID: list, due: due, dueHasTime: true, priority: 0, isCompleted: false, created: nil)
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

    @Test func onlyTheDefaultBrowsersNotificationsPass() {
        let chrome = "com.google.chrome"
        #expect(WebNotificationSource.isFromOtherBrowser("app.zen-browser.zen", defaultBrowser: chrome))
        let helper = "com.google.Chrome.framework.AlertNotificationService"
        #expect(!WebNotificationSource.isFromOtherBrowser(helper, defaultBrowser: "com.google.Chrome"))
        #expect(WebNotificationSource.isFromOtherBrowser("com.apple.Safari.WebPush.abc", defaultBrowser: chrome))
        // Web apps and ordinary apps always pass.
        #expect(!WebNotificationSource.isFromOtherBrowser("com.apple.Safari.WebApp.1234", defaultBrowser: chrome))
        #expect(!WebNotificationSource.isFromOtherBrowser("com.ardia.browser.app.gmail", defaultBrowser: chrome))
        #expect(!WebNotificationSource.isFromOtherBrowser("com.automattic.beeper.desktop", defaultBrowser: chrome))
        #expect(!WebNotificationSource.isFromOtherBrowser("app.zen-browser.zen", defaultBrowser: nil))
    }

    @Test func tabsAreReadFromScriptableDefaultBrowsersOnly() {
        #expect(BrowserTabBadges.browser(defaultBrowser: "com.ardia.browser")?.titleKey == "title")
        #expect(BrowserTabBadges.browser(defaultBrowser: "com.apple.Safari")?.titleKey == "name")
        #expect(BrowserTabBadges.browser(defaultBrowser: "app.zen-browser.zen") == nil)
    }

    @Test func highlightedNetworksTakeTheirShareOfBeepersBadge() {
        #expect(BeeperNetworkBadge.remainder("7", minus: 3) == "4")
        #expect(BeeperNetworkBadge.remainder("3", minus: 3) == nil)
        #expect(BeeperNetworkBadge.remainder("5", minus: 0) == "5")
        let beeper = BadgeApp(bundleID: "com.automattic.beeper.desktop", name: "Beeper", isEnabled: true, icon: .app)
        let synced = BeeperNetworkBadge.synced([beeper, BeeperNetworkBadge.app("WhatsApp")], networks: ["Google Chat"])
        #expect(synced.map(\.bundleID) == [beeper.bundleID, "beeper-network:Google Chat"])
        #expect(BadgeApp.chatTab(for: BeeperNetworkBadge.app("Google Chat")) == .network("Google Chat"))
    }

    @Test func networkTabsFollowBeeperAndSurviveRelaunch() {
        let tabs = NotificationsTab.shown(mail: false, networks: ["WhatsApp"])
        #expect(tabs == [.all, .chats, .beeper, .network("WhatsApp"), .googleChat])
        #expect(NotificationsTab(rawValue: NotificationsTab.network("WhatsApp").rawValue) == .network("WhatsApp"))
        #expect(NotificationsTab(rawValue: "beeper") == .beeper)
        #expect(!NotificationsTab.network("WhatsApp").isWide)
    }

    @Test func theIPadIsChosenInTheKeyboardSection() {
        let titles = ["Mirror or extend to", "iPad", "", "Link keyboard and mouse to", "iPad"]
        let enabled = [false, true, true, false, true]
        #expect(UniversalControlLink.linkItemIndex(titles: titles, enabled: enabled, name: "iPad") == 4)
        // Only in the first section: not the link item.
        #expect(UniversalControlLink.linkItemIndex(titles: ["Mirror or extend to", "iPad"], enabled: [false, true], name: "iPad") == nil)
    }
}
