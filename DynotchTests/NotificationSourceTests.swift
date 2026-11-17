@testable import Dynotch
import Foundation
import Testing

/// Spec E-15: every website a browser shows notifications for is its own source with rules.
@MainActor
struct NotificationSourceTests {
    private func makeService() -> NotificationService {
        let name = "NotificationSourceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return NotificationService(settings: AppSettings(defaults: defaults))
    }

    private func zen(site: String?) -> AppNotification {
        var notification = AppNotification(
            id: 7, appIdentifier: "app.zen-browser.zen", title: "Team", subtitle: "", body: "hi", date: Date()
        )
        notification.site = site
        return notification
    }

    @Test func aSiteWithoutWebAppBecomesItsOwnSource() {
        let service = makeService()
        let attributed = service.attribute(zen(site: "calendar.google.com"))
        #expect(attributed.appIdentifier == "web:calendar.google.com")
        #expect(attributed.sourceIdentifier == "app.zen-browser.zen")
        #expect(service.preferences.sites == ["calendar.google.com": "app.zen-browser.zen"])
        #expect(service.siteApps.map(\.name) == ["Google Calendar"])
        #expect(service.siteApps.first?.site == "calendar.google.com")

        // Without a site it stays the browser's.
        #expect(service.attribute(zen(site: nil)).appIdentifier == "app.zen-browser.zen")
        // Other apps are left alone.
        let beeper = AppNotification(
            id: 8, appIdentifier: "com.automattic.beeper.desktop", title: "A", subtitle: "", body: "b", date: Date()
        )
        #expect(service.attribute(beeper).appIdentifier == "com.automattic.beeper.desktop")
    }

    @Test func sitesStartLikeTheirBrowserExceptGmailAndChat() {
        let service = makeService()
        _ = service.attribute(zen(site: "calendar.google.com"))
        _ = service.attribute(zen(site: "chat.google.com"))
        let calendar = service.catalog.app(for: "web:calendar.google.com")
        let chat = service.catalog.app(for: "web:chat.google.com")
        // Zen itself is off by default, Google Chat is shown as before.
        #expect(!service.isEnabled(calendar))
        #expect(service.isEnabled(chat))
        service.settings.setNotificationApp(calendar.identifier, enabled: true)
        #expect(service.isEnabled(calendar))
    }

    @Test func rulesChangeNameBannerAndReply() {
        let service = makeService()
        _ = service.attribute(zen(site: "chat.google.com"))
        let chat = service.catalog.app(for: "web:chat.google.com")
        #expect(service.canReply(to: zen(site: "chat.google.com").with(appIdentifier: chat.identifier)))
        #expect(service.hidesBanner(for: chat.identifier) == service.settings.hideNativeBanners)

        service.setRule(NotificationRule(name: "  Work chat ", hidesBanner: false, showsReply: false), for: chat)
        #expect(service.catalog.app(for: chat.identifier).name == "Work chat")
        #expect(!service.hidesBanner(for: chat.identifier))
        #expect(!service.canReply(to: zen(site: "chat.google.com").with(appIdentifier: chat.identifier)))

        // Back to the defaults: the rule is gone.
        service.setRule(NotificationRule(name: " ", hidesBanner: nil, showsReply: nil), for: chat)
        #expect(service.preferences.rules.isEmpty)
        #expect(service.catalog.app(for: chat.identifier).name == "Google Chat")
    }

    @Test func sitesAndRulesArePersisted() {
        let name = "NotificationSourceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let first = NotificationPreferences(defaults: defaults)
        first.register(site: "app.slack.com", browser: "app.zen-browser.zen")
        first.setRule(NotificationRule(name: nil, hidesBanner: true, showsReply: nil), for: "web:app.slack.com")
        let again = NotificationPreferences(defaults: defaults)
        #expect(again.sites["app.slack.com"] == "app.zen-browser.zen")
        #expect(again.rule(for: "web:app.slack.com").hidesBanner == true)
        #expect(WebNotificationSource.displayName(forSite: "www.example.com") == "example.com")
        #expect(WebNotificationSource.site(fromIdentifier: "web:app.slack.com") == "app.slack.com")
        #expect(WebNotificationSource.site(fromIdentifier: "com.slack") == nil)
    }
}
