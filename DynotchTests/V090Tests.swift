@testable import Dynotch
import Foundation
import Testing

/// Tasks lists beside today's, the terminal's dropped paths and wings.
@MainActor
struct V090Tests {
    private func task(_ id: String, list: String, due: Date?) -> ReminderItem {
        ReminderItem(id: id, title: id, listID: list, due: due, dueHasTime: true, priority: 0, isCompleted: false, created: nil)
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

    @Test func droppedPathsAreQuotedForTheShell() {
        #expect(TerminalPaths.quoted(["/tmp/a b"]) == "'/tmp/a b'")
        #expect(TerminalPaths.quoted(["/x/it's", "/y"]) == #"'/x/it'\''s' '/y'"#)
    }

    @Test func terminalWingCountsTabs() {
        #expect(TerminalWing.tabs(0) == "No shell running")
        #expect(TerminalWing.tabs(1) == "1 tab")
        #expect(TerminalWing.tabs(3) == "3 tabs")
    }
}

/// Beeper's networks from its accounts.
struct V090BeeperTests {
    @Test func accountNetworksDecodeFromArrayOrItems() {
        let array = Data(#"[{"accountID":"a","network":"Telegram"},{"accountID":"b","network":"Google Chat"},{"network":"Telegram"}]"#.utf8)
        #expect(BeeperAccounts.networks(from: array) == ["Telegram", "Google Chat"])
        let page = Data(#"{"items":[{"network":"Signal"}]}"#.utf8)
        #expect(BeeperAccounts.networks(from: page) == ["Signal"])
    }

    @Test func networksMergeWithTheChatsSpelling() {
        let merged = BeeperAccounts.merged(chats: ["Google Chat", "WhatsApp"], accounts: ["googlechat", "Telegram"], highlighted: [])
        #expect(merged == ["Google Chat", "Telegram", "WhatsApp"])
    }
}
