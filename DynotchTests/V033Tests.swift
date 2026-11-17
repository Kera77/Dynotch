@testable import Dynotch
import Foundation
import Testing

/// v0.33: websites from earlier browser notifications (spec E-15b), the rounded notch (spec N-11).
@MainActor
struct V033Tests {
    private func makeSettings() -> AppSettings {
        let name = "V033Tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return AppSettings(defaults: defaults)
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

    @Test func roundedNotchIsOnByDefaultAndRemembered() {
        let name = "V033Tests-rounded-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: defaults)
        #expect(settings.roundedNotch)
        settings.roundedNotch = false
        #expect(!AppSettings(defaults: defaults).roundedNotch)
    }

    @Test func oneRowGetsRoundEnds() {
        #expect(abs(NotchCorners.radius(notchHeight: 32) - 16) < 0.001)
        #expect(abs(NotchCorners.radius(notchHeight: 37) - 19) < 0.001)
    }
}
