@testable import Dynotch
import Foundation
import Testing

/// v0.95: the module switcher's own row (QS-10…QS-12).
struct V095Tests {
    @Test func startsOnTheRowsLatestModule() {
        let row: [FeatureID] = [.calendar, .notes, .calculator]
        let history: [FeatureID] = [.terminal, .calculator, .calendar]
        // The row keeps its order; the latest opened of it is chosen (spec QS-11).
        #expect(ModuleSwitcher.startIndex(row, history: history, current: nil) == 2)
        // Open now: the one opened before it.
        #expect(ModuleSwitcher.startIndex(row, history: history, current: .calculator) == 0)
        // No history: the first, or the second if the first is open.
        #expect(ModuleSwitcher.startIndex(row, history: [], current: nil) == 0)
        #expect(ModuleSwitcher.startIndex(row, history: [], current: .calendar) == 1)
        #expect(ModuleSwitcher.startIndex([.notes], history: [.notes], current: .notes) == 0)
    }

    @Test func oneRowShrinksOnlyWhenItMust() {
        // Plenty of room: the chosen size stays (spec QS-12).
        #expect(ModuleSwitcher.rowScale(count: 6, scale: 1, width: 1400) == 1)
        let scale = ModuleSwitcher.rowScale(count: 20, scale: 1, width: 1000)
        #expect(scale < 1)
        let tile = SwitcherLayout.tile(.icons, scale: scale).width
        #expect(20 * tile + 19 * SwitcherLayout.spacing + 2 * SwitcherLayout.padding <= 1000.5)
    }

    @MainActor @Test func rowIsSeededOnceThenEdited() throws {
        let defaults = try #require(UserDefaults(suiteName: "V095Tests.row"))
        defaults.removePersistentDomain(forName: "V095Tests.row")
        let settings = SwitcherSettings(defaults: defaults)
        settings.seedModuleRow([.calendar, .notes])
        #expect(settings.moduleRow == [.calendar, .notes])
        settings.addToModuleRow(.terminal)
        settings.addToModuleRow(.notes)
        settings.moveInModuleRow(from: IndexSet(integer: 2), to: 0)
        settings.removeFromModuleRow(.calendar)
        #expect(settings.moduleRow == [.terminal, .notes])
        // A later launch keeps the edited row, even an empty one (spec QS-10).
        settings.removeFromModuleRow(.terminal)
        settings.removeFromModuleRow(.notes)
        let again = SwitcherSettings(defaults: defaults)
        again.seedModuleRow([.calendar])
        #expect(again.moduleRow.isEmpty)
    }

    @Test func chatSourcesHaveTheirOwnPage() {
        // Beeper, Google Chat and Gmail move to Settings › Chats; the rest stay (spec SD-6).
        #expect(ChatSourceKind.of(identifier: "com.automattic.beeper.desktop", name: "Beeper", site: nil) == .beeper)
        #expect(ChatSourceKind.of(identifier: "web:chat.google.com", name: "chat.google.com", site: "chat.google.com") == .googleChat)
        #expect(ChatSourceKind.of(identifier: "com.apple.Safari.WebApp.123", name: "Google Chat", site: nil) == .googleChat)
        #expect(ChatSourceKind.of(identifier: "com.apple.Safari.WebApp.456", name: "Gmail", site: nil) == .gmail)
        #expect(ChatSourceKind.of(identifier: "web:mail.google.com", name: "Mail", site: "mail.google.com") == .gmail)
        #expect(ChatSourceKind.of(identifier: "com.tinyspeck.slackmacgap", name: "Slack", site: nil) == nil)
        #expect(ChatSourceKind.of(identifier: "com.apple.mail", name: "Mail", site: nil) == nil)
    }
}
