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
        "1.8.2": [
            TestPlanItem(
                id: "narrow-notification", group: "Slimmer notifications",
                text: "A short notification (and a device notice) hangs under the notch only as wide as the notch; a long one is wider.",
                log: "notifications"
            ),
            TestPlanItem(
                id: "cleaner-scan", group: "Cleaner",
                text: "Cleaner scans by itself on first open; Leftovers shows only apps you removed, Caches lists sizes.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "cleaner-clean", group: "Cleaner",
                text: "Clean asks first, moves the ticked items to the Trash and shows Freed …; they can be put back.",
                log: "cleaner"
            ),
            TestPlanItem(
                id: "cleaner-uninstall", group: "Cleaner",
                text: "Apps › pick a test app: its files are listed; Uninstall moves the app and the ticked files to the Trash.",
                log: "cleaner"
            )
        ],
        "1.8.1": [
            TestPlanItem(
                id: "sessions-list", group: "Sessions tab",
                text: "AI › Sessions lists your Claude Code sessions: Working while it runs, Finished when done, with the prompt.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "sessions-open", group: "Sessions tab",
                text: "Clicking a session brings its VS Code window forward; Clear finished and right-click Remove work.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "answer-question", group: "Answers from the notch",
                text: "Switch to another app; when Claude asks a question, its options show as buttons and a click answers it.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "answer-permission", group: "Answers from the notch",
                text: "A permission request shows the command with Allow and Deny; both reach Claude Code.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "answer-pass", group: "Answers from the notch",
                text: "With VS Code in front, or after the X, Claude Code asks in VS Code as before, without delay.",
                log: "claude-hook"
            ),
            TestPlanItem(
                id: "test-list", group: "Test list",
                text: "Settings › Testing shows this list; Works / Broken, a note and Copy report (with the log) work.",
                log: "updates"
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
