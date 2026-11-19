@testable import Dynotch
import Foundation
import Testing

/// v0.62: hiding a badge for a while (spec B-11) and web apps' notifications (spec E-13d, B-10d).
struct V062Tests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func aHiddenBadgeComesBackAfterItsTime() {
        let hour = BadgeHide.make(.hour, label: "2", now: now)
        let hidden = ["a": hour, "b": BadgeHide.always]
        #expect(BadgeHide.remaining(hidden, labels: ["a": "2", "b": "1"], now: now.addingTimeInterval(1800)).count == 2)
        let later = BadgeHide.remaining(hidden, labels: ["a": "2", "b": "1"], now: now.addingTimeInterval(3601))
        #expect(later["a"] == nil)
        #expect(later["b"] == .always)
    }

    @Test func untilNewEndsWithANewMessageOrNoBadge() {
        let hidden = ["a": BadgeHide.make(.untilNew, label: "3", now: now)]
        // The same or fewer unread: still hidden.
        #expect(BadgeHide.remaining(hidden, labels: ["a": "3"], now: now).count == 1)
        #expect(BadgeHide.remaining(hidden, labels: ["a": "2"], now: now).count == 1)
        // A new one, or all read (the next one shows).
        #expect(BadgeHide.remaining(hidden, labels: ["a": "4"], now: now).isEmpty)
        #expect(BadgeHide.remaining(hidden, labels: [:], now: now).isEmpty)
    }

    @MainActor @Test func hiddenBadgesStayHiddenAfterARestart() {
        let defaults = UserDefaults(suiteName: "V062Badges-\(UUID().uuidString)") ?? .standard
        let service = BadgeService(defaults: defaults)
        service.hide("com.example.app", .always)
        #expect(BadgeService(defaults: defaults).hidden["com.example.app"] == .always)
        service.unhide("com.example.app")
        #expect(BadgeService(defaults: defaults).hidden.isEmpty)
    }

    @Test func webAppsCloseTheirOwnNotifications() {
        #expect(WebNotificationSource.isWebApp("com.apple.Safari.WebApp.2C5A3228-3039-4AB2-8E92-F201FEA08644"))
        #expect(WebNotificationSource.isWebApp("com.google.Chrome.app.jnedcpghndggobbgcbeolpkecdoefkei"))
        #expect(!WebNotificationSource.isWebApp("com.apple.mail"))
        #expect(!WebNotificationSource.isWebApp("com.apple.safari.webapp"))
    }
}

/// v0.62: spaces in the menu bar (spec MB-1…MB-6).
struct MenuBarSpacerTests {
    @MainActor @Test func spacesAreKept() {
        let defaults = UserDefaults(suiteName: "V062Spacers-\(UUID().uuidString)") ?? .standard
        let service = MenuBarSpacerService(defaults: defaults)
        let first = service.add()
        service.add()
        service.setStyle(.line, of: first.id)
        service.setWidth(.large, of: first.id)
        let reopened = MenuBarSpacerService(defaults: defaults)
        #expect(reopened.spacers.count == 2)
        #expect(reopened.spacers.first?.style == .line)
        #expect(reopened.spacers.first?.width == .large)
        reopened.remove(first.id)
        #expect(MenuBarSpacerService(defaults: defaults).spacers.count == 1)
    }
}
