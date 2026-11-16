import AppKit
import Carbon.HIToolbox
@testable import Dynotch
import Foundation
import Testing

/// Smaller behaviours fixed in 0.24.
@MainActor
struct FixesTests {
    // MARK: - Calls (spec P-1)

    @Test func theCallerIsTheFirstPartOfTheBannerLine() {
        let banner = CallMatcher.describe(texts: ["Phone", "\u{202A}Terence Szivattyús\u{202C}, P, From Your iPhone"])
        #expect(banner.caller == "Terence Szivattyús")
        #expect(banner.detail == "From Your iPhone")
        #expect(CallMatcher.clean("\u{202A}Anna\u{202C} ") == "Anna")
        #expect(CallMatcher.isChrome("Phone"))
    }

    @Test func aMessageGoesToTheNumberThenMailThenTheName() {
        let contact = CallerContact(name: "Anna Kis", number: "+36 30 123 4567", emails: ["anna@example.com"], imageData: nil)
        #expect(CallMessenger.targets(for: "Anna Kis", contact: contact) == ["+36 30 123 4567", "anna@example.com", "Anna Kis"])
        // Not in Contacts: Messages may still know the name.
        #expect(CallMessenger.targets(for: "Anna Kis", contact: CallerContact()) == ["Anna Kis"])
        #expect(CallMessenger.targets(for: "+36 30 123 4567", contact: CallerContact(number: "+36 30 123 4567")) == ["+36 30 123 4567"])
        #expect(CallMessenger.targets(for: CallMatcher.unknownCaller, contact: CallerContact()).isEmpty)
    }

    // MARK: - Notifications (spec E-13)

    @Test func notificationsHandledInTheirAppAreDropped() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func notification(_ id: Int64, age: TimeInterval) -> AppNotification {
            AppNotification(id: id, appIdentifier: "x", title: "t", subtitle: "", body: "b", date: now.addingTimeInterval(-age))
        }
        let recent = [notification(12, age: 2), notification(11, age: 60), notification(10, age: 90), notification(-1, age: 90)]
        var asked: Int64?
        let gone = NotificationCleanup.handled(recent: recent, now: now) { lowest in
            asked = lowest
            return [10, 12]
        }
        // 11 was read in its app; 12 is too new to judge, -1 is Dynotch's own.
        #expect(gone == [11])
        #expect(asked == 10)
        #expect(NotificationCleanup.handled(recent: [notification(-1, age: 90)], now: now) { _ in [] }.isEmpty)
    }

    @Test func theBeeperTokenIsKeptInAPrivateFile() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("token-\(UUID().uuidString)")
        #expect(BeeperClient.token(file: file) == nil)
        BeeperClient.setToken("  abc123\n", file: file)
        #expect(BeeperClient.token(file: file) == "abc123")
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)
        BeeperClient.setToken("", file: file)
        #expect(BeeperClient.token(file: file) == nil)
    }

    // MARK: - Focus (spec F-8)

    @Test func aWindowThatRefusesFocusIsLeftAlone() {
        var attempts = FocusRules.Attempts()
        #expect(attempts.shouldTry(7))
        #expect(attempts.shouldTry(7))
        #expect(!attempts.shouldTry(7))
        // Another window starts over.
        #expect(attempts.shouldTry(8))
        #expect(attempts.shouldTry(7))
        attempts.reset()
        #expect(attempts.shouldTry(7))
        #expect(FocusRules.isDialog(subrole: "AXDialog"))
        #expect(FocusRules.isDialog(subrole: "AXSystemDialog"))
        #expect(!FocusRules.isDialog(subrole: "AXStandardWindow"))
    }

    // MARK: - Pin shortcut (spec SC-3)

    @Test func thePinShortcutIsStoredAndUnique() throws {
        let name = "FixesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let store = ShortcutStore(defaults: defaults)
        let shortcut = try #require(KeyShortcut.make(keyCode: UInt16(kVK_ANSI_L), flags: [.option], characters: "l"))
        store.set(shortcut, for: .notes)
        store.setPinShortcut(shortcut)
        #expect(store.pinShortcut == shortcut)
        #expect(store.shortcuts.isEmpty)
        #expect(ShortcutStore(defaults: defaults).pinShortcut == shortcut)

        store.set(shortcut, for: .calculator)
        #expect(store.pinShortcut == nil)
        #expect(store.shortcuts == [.calculator: shortcut])
    }
}
