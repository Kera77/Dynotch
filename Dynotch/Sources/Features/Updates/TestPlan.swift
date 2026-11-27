import Foundation
import Observation

/// One thing to check in a test build, and the log to send when it fails (spec TL-1).
struct TestPlanItem: Sendable, Hashable, Identifiable {
    let id: String
    let group: String
    let text: String
    /// The file in `~/Library/Logs/Dynotch` without `.log`.
    let log: String
}

/// What to test in each test build (spec TL-1). The release writes the owner's test list from here.
enum TestPlan {
    static let plans: [String: [TestPlanItem]] = [
        "1.8.8": [
            TestPlanItem(
                id: "session-hover", group: "AI sessions",
                text: "Hover the usage ring, rest on a session: it opens with Task, Now and Answer; moving off folds it back.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "overdue-swipe", group: "Tasks",
                text: "Swipe the overdue row under the closed notch up with two fingers: it goes away and comes back after 30 minutes.",
                log: "reminders"
            ),
            TestPlanItem(
                id: "disk-order", group: "Cleaner",
                text: "The disk bar and its labels run from the largest part to the smallest (Free included); labels wrap.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "disk-other", group: "Cleaner",
                text: "After a scan the bar shows System, App data and Files besides Apps and Caches; a label's hover says what it holds.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "app-circles", group: "Cleaner",
                text: "Apps: size, arrow, then two equal circles (green Open or blue X Quit, red bin); sizes line up.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "app-grow", group: "Cleaner",
                text: "Click a circle: it grows into Open, Quit or Uninstall; click again to do it; it folds back after 4 s.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "app-uninstall-running", group: "Cleaner",
                text: "Uninstall a running app from its row or details (bin, then the footer question): it quits, then goes.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "cleaner-ring", group: "Cleaner",
                text: "Close the notch while cleaning: a blue arc runs round a ring with sparkles, then the ring fills green with a tick.",
                log: "cleaner"
            )
        ],
        "1.8.7": [
            TestPlanItem(
                id: "overdue-row", group: "Tasks",
                text: "An overdue task: one thin red row under the notch (oldest task, +N); hovering it opens the tasks list.",
                log: "reminders"
            ),
            TestPlanItem(
                id: "overdue-later", group: "Tasks",
                text: "There an overdue task has a clock (Later: back in an hour), an X (gone until its date changes) and the circle.",
                log: "reminders"
            ),
            TestPlanItem(
                id: "task-colour", group: "Tasks",
                text: "The task counter turns orange an hour before a timed task is due, red while one is overdue.",
                log: "reminders"
            ),
            TestPlanItem(
                id: "session-click", group: "AI sessions",
                text: "Hover the usage ring: click a session row, its app comes forward with the project's window.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "session-detail", group: "AI sessions",
                text: "Session rows show the app's icon and a second line: the step while working, the answer's first line when finished.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "month-tile", group: "Home",
                text: "The 1x2 Month tile is as big as the Ask tile and does not overlap its neighbours, also with the notch made small.",
                log: "home"
            ),
            TestPlanItem(
                id: "cleaner-row-uninstall", group: "Cleaner",
                text: "Apps › Uninstall in a row asks in the row, then moves the app with its files to the Trash without opening it.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "cleaner-quit", group: "Cleaner",
                text: "A running app has a blue Quit in its row and details; it quits without asking, then Uninstall shows.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "cleaner-detail-column", group: "Cleaner",
                text: "Click an app: its details slide in from the right (Quit/Uninstall, size, files); X or a swipe closes them.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "cleaner-bar-large", group: "Cleaner",
                text: "Disk bar, last used dates with Size/Last used sort, Large files tab (files over 500 MB), bigger text.",
                log: "cleaner"
            )
        ],
        "1.8.6": [
            TestPlanItem(
                id: "task-month-scroll", group: "Tasks",
                text: "Task details › Date › click the day capsule: the details scroll so the whole month shows.",
                log: "reminders"
            ),
            TestPlanItem(
                id: "cleaner-from-stats", group: "Cleaner",
                text: "Stats › Disk › Clean opens the Cleaner (no Cleaner module any more); ‹ Stats and a pinch go back.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "cleaner-entry-points", group: "Cleaner",
                text: "Clean on the Home's Disk and Cleaner tiles, and the Cleaner button in the top row (switch it on in Settings).",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "cleaner-busy", group: "Cleaner",
                text: "Clean something: the whole Cleaner is covered with Cleaning… and can't be clicked until it's done; ticks are round.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "cleaner-notch-tick", group: "Cleaner",
                text: "Close the notch while cleaning: spinner right of the notch, then a green tick; hovering it opens the Cleaner.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "cleaner-app-swipe", group: "Cleaner",
                text: "Apps › open an app: a two-finger sideways swipe goes back to the list without changing module.",
                log: "cleaner"
            )
        ],
        "1.8.5": [
            TestPlanItem(
                id: "sessions-claude-app", group: "Claude Code sessions",
                text: "Sessions in VS Code, the Claude app (Code tab) and a terminal all show in AI › Sessions, each with its app's icon.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "sessions-after-restart", group: "Claude Code sessions",
                text: "Quit and reopen Dynotch: within ~10 s running sessions are back as Ready; a click brings the right app forward.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "notice-second-x", group: "Notices",
                text: "With two notices under the notch (e.g. Claude and Codex done), the lower one has an X; it removes only that one.",
                log: "notch"
            ),
            TestPlanItem(
                id: "task-date-editor", group: "Task details",
                text: "Task details: set the day with the chips or the small month, the time with the chips and arrows; Done saves it.",
                log: "reminders"
            ),
            TestPlanItem(
                id: "task-menus", group: "Task details",
                text: "Repeat, Early Reminder, List and Priority open their menus from the capsules; the notch stays open meanwhile.",
                log: "reminders"
            )
        ],
        "1.8.4": [
            TestPlanItem(
                id: "usage-popup-flash", group: "Sessions at the usage ring",
                text: "Start a new Claude Code session: the usage drops down and goes by itself after ~6 s; hovered it stays.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "usage-popup-flick", group: "Sessions at the usage ring",
                text: "Start another session and flick the drop-down up with two fingers: it goes at once.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "usage-follow-toggle", group: "Sessions at the usage ring",
                text: "Settings › General › AI usage: turn off the drop-down, then the following; a new session no longer drops down.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "beeper-badge-chats", group: "Beeper",
                text: "Hover the Beeper badge and click a chat: the Chats tab opens with that chat's card open, ready to type.",
                log: "beeper"
            ),
            TestPlanItem(
                id: "beeper-send-steady", group: "Beeper",
                text: "Send two messages from a card: the field empties without a selection, the notch stays, messages slide up.",
                log: "beeper"
            )
        ],
        "1.8.3": [
            TestPlanItem(
                id: "usage-sessions", group: "Sessions at the usage ring",
                text: "Hover the AI ring beside the notch: under the limits your running Claude Code sessions show with state and time.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "usage-popup", group: "Sessions at the usage ring",
                text: "Start a new Claude Code session: the usage drops down by itself; its X closes it until the next session.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "usage-popup-gone", group: "Sessions at the usage ring",
                text: "When the session finished and you don't touch it, the drop-down goes by itself after about 10 minutes.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "beeper-stays", group: "Chat cards stay while you reply",
                text: "Click into a Beeper card's reply field: it stays; send two messages, both show on the right as yours.",
                log: "beeper"
            ),
            TestPlanItem(
                id: "gchat-stays", group: "Chat cards stay while you reply",
                text: "The same with a Google Chat notification; the card goes only when you close it or click away.",
                log: "google-chat-web"
            ),
            TestPlanItem(
                id: "chat-bubbles", group: "Chat cards stay while you reply",
                text: "In Beeper and Google Chat cards the others' messages are on the left, yours on the right, sliding in.",
                log: "notifications"
            )
        ]
    ]

    /// The running test build's list, if it has one.
    static var current: [TestPlanItem]? {
        plan(for: AppInfo.version)
    }

    static func plan(for version: String) -> [TestPlanItem]? {
        guard UpdateLogic.isTestBuild(version), let plan = plans[version], !plan.isEmpty else { return nil }
        return plan
    }

    /// The items by group, in the order they come.
    static func groups(_ items: [TestPlanItem]) -> [(name: String, items: [TestPlanItem])] {
        var names: [String] = []
        for item in items where !names.contains(item.group) { names.append(item.group) }
        return names.map { name in (name, items.filter { $0.group == name }) }
    }
}

/// Works / Broken and the notes of one version's test list, kept per version (spec TL-2, TL-3).
@MainActor
@Observable
final class TestPlanStore {
    enum Status: String, Sendable {
        case works, broken
    }

    let version: String
    let items: [TestPlanItem]
    private(set) var statuses: [String: Status]
    private(set) var notes: [String: String]
    @ObservationIgnored private let defaults: UserDefaults

    init(version: String, items: [TestPlanItem], defaults: UserDefaults = .standard) {
        self.version = version
        self.items = items
        self.defaults = defaults
        let saved = defaults.dictionary(forKey: "testPlan.\(version)") as? [String: String] ?? [:]
        statuses = saved.compactMapValues(Status.init(rawValue:))
        notes = defaults.dictionary(forKey: "testPlan.\(version).notes") as? [String: String] ?? [:]
    }

    var checked: Int { items.filter { statuses[$0.id] != nil }.count }

    func set(_ status: Status?, for item: TestPlanItem) {
        statuses[item.id] = status
        defaults.set(statuses.mapValues(\.rawValue), forKey: "testPlan.\(version)")
        DiagnosticsLog.append("updates", "test \(version) \(item.id): \(status?.rawValue ?? "unchecked")")
    }

    func setNote(_ note: String, for item: TestPlanItem) {
        notes[item.id] = note.isEmpty ? nil : note
        defaults.set(notes, forKey: "testPlan.\(version).notes")
    }

    /// Markdown for the owner to paste: every item, and for broken ones the note and the log (spec TL-3).
    func report(only item: TestPlanItem? = nil, logTail: (String) -> String = TestPlanStore.logTail) -> String {
        var lines = ["## Wingmate \(version) test" + (item == nil ? " (\(checked) of \(items.count) checked)" : "")]
        for entry in item.map({ [$0] }) ?? items {
            let mark = switch statuses[entry.id] {
            case .works: "✅"
            case .broken: "❌"
            case nil: "⬜️"
            }
            lines.append("- \(mark) **\(entry.group):** \(entry.text)")
            guard statuses[entry.id] == .broken else { continue }
            if let note = notes[entry.id] { lines.append("  - Note: \(note)") }
            lines += ["", "  `\(entry.log).log` (last lines):", "```", logTail(entry.log), "```"]
        }
        return lines.joined(separator: "\n")
    }

    /// The last 40 lines of a log (spec TL-3).
    nonisolated static func logTail(_ name: String) -> String {
        let file = DiagnosticsLog.directory.appendingPathComponent("\(name).log")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return "(no \(name).log)" }
        return text.split(separator: "\n", omittingEmptySubsequences: false).suffix(40).joined(separator: "\n")
    }

    /// The notice after an update is shown once per version (spec TL-4).
    static func shouldAnnounce(_ version: String, defaults: UserDefaults = .standard) -> Bool {
        guard TestPlan.plan(for: version) != nil, defaults.string(forKey: "testPlanAnnounced") != version else { return false }
        defaults.set(version, forKey: "testPlanAnnounced")
        return true
    }
}
