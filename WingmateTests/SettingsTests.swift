import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

/// The settings window: modules, tabs and the Chats page (spec M-3, SD-6).
@MainActor
struct SettingsTests {
    private func makeDefaults() -> UserDefaults {
        let name = "SettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Spec M-3: dragging a row in the Modules tab moves it.
    @Test func modulesMoveByDragging() {
        let settings = AppSettings(defaults: makeDefaults())
        let order = settings.featureOrder
        // Down: the dragged row lands after the target.
        settings.moveFeatures(from: IndexSet(integer: 0), to: 3)
        #expect(settings.featureOrder[2] == order[0])
        // Up: the dragged row lands on the target's place.
        settings.moveFeatures(from: IndexSet(integer: 2), to: 0)
        #expect(settings.featureOrder == order)
    }

    @Test func appearanceHasItsOwnTab() {
        #expect(SettingsTab.allCases.contains(.appearance))
        #expect(SettingsTab.appearance.title == "Appearance")
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
