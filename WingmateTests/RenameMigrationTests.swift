import Foundation
import Testing
@testable import Wingmate

/// The one-time takeover from the old name (spec RN-3, RN-6).
struct RenameMigrationTests {
    @Test func storedValuesGetTheNewName() throws {
        #expect(RenameMigration.renamed("dynotchAlertsOff") == "wingmateAlertsOff")
        #expect(RenameMigration.renamed(value: ["dynotch.mail", 3]) as? [AnyHashable] == ["wingmate.mail", 3])
        let nested = RenameMigration.renamed(value: ["Dynotch": ["x": "dynotch.claude"]]) as? [String: [String: String]]
        #expect(nested == ["Wingmate": ["x": "wingmate.claude"]])
        let json = try #require(RenameMigration.renamed(value: Data(#"["dynotch.gmail"]"#.utf8)) as? Data)
        #expect(String(data: json, encoding: .utf8) == #"["wingmate.gmail"]"#)
        let archive = Data([0x62, 0x70, 0x6C, 0x69, 0x73, 0x74])
        #expect(RenameMigration.renamed(value: archive) as? Data == archive)
    }

    @Test func settingsAreCopiedWithoutOverwriting() {
        let name = "RenameMigrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("new", forKey: "kept")
        let old: [String: Any] = ["dynotchAlertsOff": ["dynotch.web.teams"], "kept": "old", "launchAtLoginBeforeRename": true]
        #expect(RenameMigration.copySettings(old, into: defaults) == 1)
        #expect(defaults.stringArray(forKey: "wingmateAlertsOff") == ["wingmate.web.teams"])
        #expect(defaults.string(forKey: "kept") == "new")
        #expect(defaults.object(forKey: "launchAtLoginBeforeRename") == nil)
    }

    @Test func onlyTheOldAppsHooksAreTakenOut() {
        let other: [String: Any] = ["hooks": [["type": "command", "command": "say done"]]]
        let old: [String: Any] = ["hooks": [["type": "command", "command": #"open -g "dynotch://claude-finished""#]]]
        let events: [String: Any] = ["Stop": [other, old], "Notification": [old], "Other": "x"]
        let (kept, removed) = RenameMigration.withoutOldHooks(events)
        #expect(removed.count == 2)
        #expect((kept["Stop"] as? [[String: Any]])?.count == 1)
        #expect(kept["Notification"] == nil)
        #expect(kept["Other"] as? String == "x")
    }
}
