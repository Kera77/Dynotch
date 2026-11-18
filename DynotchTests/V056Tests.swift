@testable import Dynotch
import Foundation
import Testing

struct V056Tests {
    private func web(_ id: Int64, body: String = "hello") -> AppNotification {
        AppNotification(
            id: id, appIdentifier: "web:chat.google.com", title: "Space", subtitle: "", body: body, date: Date()
        )
        .withSource("app.zen-browser.zen")
    }

    @Test func websiteNotificationsAreKeptAfterLeavingNotificationCenter() {
        #expect(web(5).isFromBrowser)
        let beeper = AppNotification(
            id: 6, appIdentifier: "com.automattic.beeper.desktop", title: "A", subtitle: "", body: "b", date: Date()
        )
        #expect(!beeper.isFromBrowser)
    }

    @Test func aRekeyedNotificationKeepsItsContent() {
        let kept = web(5).with(id: -3)
        #expect(kept.id == -3)
        #expect(kept.isFromBrowser)
        #expect(kept.body == "hello")
    }

    @Test func aRepostedMessageReplacesTheKeptCopy() {
        let kept = web(5).with(id: -3)
        #expect(web(9).repeats(kept))
        #expect(!web(9, body: "other").repeats(kept))
    }
}

private extension AppNotification {
    func withSource(_ source: String) -> AppNotification {
        var copy = self
        copy.sourceIdentifier = source
        return copy
    }
}
