import Foundation
import Testing
@testable import Wingmate

/// Notifications from websites and web apps (spec E-13d, E-15b).
@MainActor
struct WebNotificationsTests {
    private func makeSettings() -> AppSettings {
        let name = "WebNotificationsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return AppSettings(defaults: defaults)
    }

    private func web(_ id: Int64, body: String = "hello") -> AppNotification {
        AppNotification(
            id: id, appIdentifier: "web:chat.google.com", title: "Space", subtitle: "", body: body, date: Date()
        )
        .withSource("app.zen-browser.zen")
    }

    @Test func earlierBrowserNotificationsListTheirSites() {
        let service = NotificationService(settings: makeSettings())
        service.registerSites([
            (browser: "app.zen-browser.zen", site: "calendar.google.com"),
            (browser: "app.zen-browser.zen", site: "calendar.google.com"),
            (browser: "org.mozilla.firefox", site: "github.com")
        ])
        #expect(service.preferences.sites == [
            "calendar.google.com": "app.zen-browser.zen", "github.com": "org.mozilla.firefox"
        ])
        #expect(service.siteApps.map(\.name) == ["github.com", "Google Calendar"])
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

    @Test func webAppsCloseTheirOwnNotifications() {
        #expect(WebNotificationSource.isWebApp("com.apple.Safari.WebApp.2C5A3228-3039-4AB2-8E92-F201FEA08644"))
        #expect(WebNotificationSource.isWebApp("com.google.Chrome.app.jnedcpghndggobbgcbeolpkecdoefkei"))
        #expect(!WebNotificationSource.isWebApp("com.apple.mail"))
        #expect(!WebNotificationSource.isWebApp("com.apple.safari.webapp"))
    }

    @Test func onlyTheDefaultBrowsersNotificationsPass() {
        let chrome = "com.google.chrome"
        #expect(WebNotificationSource.isFromOtherBrowser("app.zen-browser.zen", defaultBrowser: chrome))
        let helper = "com.google.Chrome.framework.AlertNotificationService"
        #expect(!WebNotificationSource.isFromOtherBrowser(helper, defaultBrowser: "com.google.Chrome"))
        #expect(WebNotificationSource.isFromOtherBrowser("com.apple.Safari.WebPush.abc", defaultBrowser: chrome))
        // Web apps and ordinary apps always pass.
        #expect(!WebNotificationSource.isFromOtherBrowser("com.apple.Safari.WebApp.1234", defaultBrowser: chrome))
        #expect(!WebNotificationSource.isFromOtherBrowser("com.ardia.browser.app.gmail", defaultBrowser: chrome))
        #expect(!WebNotificationSource.isFromOtherBrowser("com.automattic.beeper.desktop", defaultBrowser: chrome))
        #expect(!WebNotificationSource.isFromOtherBrowser("app.zen-browser.zen", defaultBrowser: nil))
    }
}

private extension AppNotification {
    func withSource(_ source: String) -> AppNotification {
        var copy = self
        copy.sourceIdentifier = source
        return copy
    }
}
