import AppKit
import Carbon.HIToolbox
@testable import Dynotch
import Foundation
import Testing

@MainActor
struct ShortcutTests {
    private func makeDefaults() -> UserDefaults {
        let name = "ShortcutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func shortcutsNeedAModifier() {
        let optionOne = KeyShortcut.make(keyCode: UInt16(kVK_ANSI_1), flags: [.option], characters: "¡")
        #expect(optionOne?.display == "⌥1")
        #expect(optionOne?.modifiers == UInt32(optionKey))
        let combo = KeyShortcut.make(keyCode: UInt16(kVK_ANSI_N), flags: [.command, .shift, .control], characters: "n")
        #expect(combo?.display == "⌃⇧⌘N")
        #expect(KeyShortcut.make(keyCode: UInt16(kVK_ANSI_N), flags: [], characters: "n") == nil)
        #expect(KeyShortcut.make(keyCode: UInt16(kVK_ANSI_N), flags: [.shift], characters: "N") == nil)
        #expect(KeyShortcut.make(keyCode: UInt16(kVK_Space), flags: [.option], characters: " ")?.display == "⌥Space")
    }

    @Test func aCombinationBelongsToOneFeature() throws {
        let defaults = makeDefaults()
        let store = ShortcutStore(defaults: defaults)
        let shortcut = try #require(KeyShortcut.make(keyCode: UInt16(kVK_ANSI_1), flags: [.option], characters: "1"))
        store.set(shortcut, for: .notes)
        store.set(shortcut, for: .calculator)
        store.setPins(.calculator, true)
        store.setPins(.notes, true)
        store.setPins(.notes, false)
        #expect(store.shortcuts == [.calculator: shortcut])

        let reloaded = ShortcutStore(defaults: defaults)
        #expect(reloaded.shortcuts == [.calculator: shortcut])
        // Spec SC-2: pinning is chosen per feature.
        #expect(reloaded.pins(.calculator))
        #expect(!reloaded.pins(.notes))
        reloaded.set(nil, for: .calculator)
        #expect(ShortcutStore(defaults: defaults).shortcuts.isEmpty)
    }

    // MARK: - Claude finished (spec CN-1, CN-2)

    @Test func theLinkBecomesANotice() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let url = try #require(URL(string: "dynotch://claude-finished?project=My%20App"))
        let notice = ClaudeHook.notice(from: url, now: now)
        #expect(notice == StickyNotice(title: "Claude finished", detail: "My App", date: now))
        let bare = try #require(URL(string: "dynotch://claude-finished"))
        #expect(ClaudeHook.notice(from: bare, now: now)?.detail.isEmpty == true)
        let other = try #require(URL(string: "dynotch://something-else"))
        #expect(ClaudeHook.notice(from: other, now: now) == nil)

        let service = NoticeService()
        service.handle(url)
        #expect(service.notice?.detail == "My App")
        service.dismiss()
        #expect(service.notice == nil)
    }

    @Test func theHookIsAddedAndRemovedWithoutTouchingOtherSettings() {
        let other: [String: Any] = ["hooks": [["type": "command", "command": "say done"]]]
        let settings: [String: Any] = ["model": "x", "hooks": ["Stop": [other], "PreToolUse": [other]]]
        #expect(!ClaudeHook.isInstalled(in: settings))

        let installed = ClaudeHook.settings(settings, installed: true)
        #expect(ClaudeHook.isInstalled(in: installed))
        #expect(installed["model"] as? String == "x")
        let hooks = installed["hooks"] as? [String: Any]
        #expect((hooks?["Stop"] as? [[String: Any]])?.count == 2)
        #expect((hooks?["PreToolUse"] as? [[String: Any]])?.count == 1)
        // Installing twice keeps one copy.
        let again = ClaudeHook.settings(installed, installed: true)
        #expect(((again["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]])?.count == 2)

        let removed = ClaudeHook.settings(installed, installed: false)
        #expect(!ClaudeHook.isInstalled(in: removed))
        #expect(((removed["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]])?.count == 1)
        #expect(ClaudeHook.settings(ClaudeHook.settings([:], installed: true), installed: false).isEmpty)
    }
}
