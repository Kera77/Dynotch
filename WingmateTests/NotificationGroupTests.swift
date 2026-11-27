import Foundation
import Testing
@testable import Wingmate

@MainActor
struct NotificationGroupTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func notification(
        _ id: Int64, app: String = "com.automattic.beeper.desktop", from title: String, at offset: TimeInterval
    ) -> AppNotification {
        AppNotification(
            id: id, appIdentifier: app, title: title, subtitle: "", body: "text \(id)", date: start.addingTimeInterval(offset)
        )
    }

    private func makeService() -> NotificationService {
        let name = "NotificationGroupTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return NotificationService(settings: AppSettings(defaults: defaults))
    }

    /// Spec E-5b: one group per sender and app, messages oldest first, newest group on top.
    @Test func groupsBySenderAndApp() {
        let list = [
            notification(4, from: "Anna", at: 40),
            notification(3, from: "Bela", at: 30),
            notification(2, from: " anna ", at: 20),
            notification(1, app: "com.other.chat", from: "Anna", at: 10)
        ]
        let groups = NotificationGroup.groups(of: list)
        #expect(groups.count == 3)
        #expect(groups[0].notifications.map(\.id) == [2, 4])
        #expect(groups[0].latest.id == 4)
        #expect(groups[1].latest.id == 3)
        #expect(groups[2].notifications.map(\.id) == [1])
        #expect(NotificationGroup.groups(of: []).isEmpty)
    }

    @Test func badgeAppsMatchByIdentifierOrName() {
        #expect(NotificationFocus.matches(
            bundleID: "com.automattic.beeper.desktop", name: "Beeper Desktop",
            identifier: "com.automattic.Beeper.Desktop", notificationAppName: "Beeper"
        ))
        #expect(NotificationFocus.matches(
            bundleID: "com.apple.Safari.WebApp.1", name: "Gmail",
            identifier: "com.apple.Safari.WebApp.2", notificationAppName: "gmail"
        ))
        #expect(!NotificationFocus.matches(
            bundleID: "com.apple.mail", name: "Mail", identifier: "com.automattic.beeper.desktop", notificationAppName: "Beeper"
        ))
    }

    /// Spec B-6: a badge click lists that app's newest notifications, as many as the badge counts.
    @Test func focusShowsTheAppsNewestNotifications() {
        let service = makeService()
        service.present(title: "Anna", body: "one", appIdentifier: "com.test.chat")
        service.present(title: "Other", body: "x", appIdentifier: "com.test.other")
        service.present(title: "Anna", body: "two", appIdentifier: "com.test.chat")
        service.present(title: "Bela", body: "three", appIdentifier: "com.test.chat")

        service.setFocus(bundleID: "com.test.chat", name: "Chat", count: 2)
        #expect(service.focus?.notifications.map(\.body) == ["three", "two"])
        service.setFocus(bundleID: "com.test.chat", name: "Chat", count: nil)
        #expect(service.focus?.notifications.count == 3)

        if let first = service.focus?.notifications.first { service.remove(first) }
        #expect(service.focus?.notifications.count == 2)
        service.clearFocus()
        #expect(service.focus == nil)
        service.clearPeek()
    }
}
