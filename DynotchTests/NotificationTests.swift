@testable import Dynotch
import Foundation
import Testing

struct NotificationTests {
    private func record(_ request: [String: Any], date: Double = 800_000_000) throws -> Data {
        let plist: [String: Any] = ["app": "com.example.app", "date": date, "req": request]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    }

    private func notification(title: String, subtitle: String = "", body: String = "") -> AppNotification {
        AppNotification(id: 1, appIdentifier: "app", title: title, subtitle: subtitle, body: body, date: Date())
    }

    @Test func parsesTitleSubtitleBodyAndDate() throws {
        let data = try record(["titl": "Anna", "subt": "Csapat", "body": " Szia! \n"])
        let parsed = try #require(NotificationParser.parse(recordID: 42, appIdentifier: "com.automattic.beeper.desktop", data: data))
        #expect(parsed.id == 42)
        #expect(parsed.appIdentifier == "com.automattic.beeper.desktop")
        #expect(parsed.title == "Anna")
        #expect(parsed.subtitle == "Csapat")
        #expect(parsed.body == "Szia!")
        #expect(parsed.date == Date(timeIntervalSinceReferenceDate: 800_000_000))
    }

    @Test func fallsBackToAppIdentifierInsideRecord() throws {
        let parsed = try #require(NotificationParser.parse(recordID: 1, appIdentifier: "", data: try record(["body": "x"])))
        #expect(parsed.appIdentifier == "com.example.app")
    }

    @Test func rejectsEmptyAndMalformedRecords() throws {
        #expect(NotificationParser.parse(recordID: 1, appIdentifier: "a", data: try record([:])) == nil)
        #expect(NotificationParser.parse(recordID: 1, appIdentifier: "a", data: Data([1, 2, 3])) == nil)
    }

    @Test func keySummaryContainsNoValues() throws {
        let summary = NotificationParser.keySummary(of: try record(["titl": "Secret sender", "body": "Secret text"]))
        #expect(summary.contains("titl"))
        #expect(!summary.contains("Secret"))
    }

    @Test func messageShowsSenderAndFullText() {
        let content = NotificationPresenter.content(
            for: notification(title: "Anna", subtitle: "Csapat", body: "Első sor\nMásodik sor"),
            appName: "Beeper Desktop", kind: .message
        )
        #expect(content.sender == "Anna")
        #expect(content.detail == "Csapat\nElső sor\nMásodik sor")
    }

    @Test func mailShowsSenderAndSubjectOnly() {
        let content = NotificationPresenter.content(
            for: notification(title: "Kovács Béla", subtitle: "mail.google.com", body: "Ajánlat frissítve\nSzia, küldöm a..."),
            appName: "Gmail", kind: .mail
        )
        #expect(content.sender == "Kovács Béla")
        #expect(content.detail == "Ajánlat frissítve")
    }

    @Test func missingTitleFallsBackToAppName() {
        let content = NotificationPresenter.content(for: notification(title: "", body: "Hello"), appName: "Google Chat", kind: .message)
        #expect(content.sender == "Google Chat")
        #expect(content.detail == "Hello")
    }

    @Test func kindAndDefaultApps() {
        #expect(NotificationKind.detect(appName: "Gmail") == .mail)
        #expect(NotificationKind.detect(appName: "Google Chat") == .message)
        #expect(NotificationApp.isDefaultEnabled(identifier: "com.automattic.beeper.desktop", name: "Beeper Desktop"))
        #expect(NotificationApp.isDefaultEnabled(identifier: "com.apple.Safari.WebApp.2C5A", name: "Gmail"))
        #expect(NotificationApp.isDefaultEnabled(identifier: "com.apple.Safari.WebApp.940A", name: "Google Chat"))
        #expect(!NotificationApp.isDefaultEnabled(identifier: "com.apple.Safari.WebApp.E390", name: "StickyPrompts"))
        #expect(!NotificationApp.isDefaultEnabled(identifier: "com.apple.mail", name: "Mail"))
    }

    @Test @MainActor func missingFullDiskAccessIsRecognized() {
        let denied = ["/a/db: open failed: authorization denied", "/b/db: open failed: unable to open database file"]
        #expect(NotificationService.failureStatus(for: denied) == .noAccess)
        #expect(NotificationService.failureStatus(for: ["/b/db: open failed: unable to open database file"]) == .noAccess)
        let broken = ["/a/db: prepare failed: no such table: record"]
        #expect(NotificationService.failureStatus(for: broken) == .unsupported(broken[0]))
    }

    private let webApps: [(identifier: String, name: String)] = [
        ("com.apple.safari.webapp.2c5a3228-3039-4ab2-8e92-f201fea08644", "Gmail"),
        ("com.apple.safari.webapp.940a8882-8516-4897-88eb-4e574d45e845", "Google Chat"),
        ("com.automattic.beeper.desktop", "Beeper Desktop")
    ]

    /// Spec E-2b: web notifications under a shared Safari identifier go to the site's web app.
    @Test func sharedSafariNotificationsAreAttributedToTheWebApp() throws {
        let gmail = try record(["titl": "Anna", "subt": "mail.google.com", "body": "Tárgy"])
        let parsed = try #require(NotificationParser.parse(recordID: 1, appIdentifier: "com.apple.safari.webapp", data: gmail))
        #expect(parsed.site == "mail.google.com")
        #expect(WebNotificationSource.resolvedIdentifier(parsed.appIdentifier, site: parsed.site, apps: webApps) == webApps[0].identifier)

        let chat: [String: Any] = [
            "app": "com.apple.Safari", "srce": "https://chat.google.com/u/0/", "req": ["titl": "Béla", "body": "hello"]
        ]
        let site = WebNotificationSource.site(in: chat)
        #expect(site == "chat.google.com")
        #expect(WebNotificationSource.resolvedIdentifier("com.apple.Safari", site: site, apps: webApps) == webApps[1].identifier)
    }

    @Test func siteIgnoresMessageTextAndBundleIdentifiers() {
        let plist: [String: Any] = [
            "app": "com.apple.safari.webapp",
            "req": ["titl": "see mail.google.com", "body": "visit chat.google.com", "thre": "group.com.apple.x"]
        ]
        #expect(WebNotificationSource.site(in: plist) == nil)
    }

    @Test func ownIdentifiersAndUnknownSitesAreKept() {
        let own = webApps[0].identifier
        #expect(WebNotificationSource.resolvedIdentifier(own, site: "chat.google.com", apps: webApps) == own)
        #expect(WebNotificationSource.resolvedIdentifier("com.apple.safari.webapp", site: "example.org", apps: webApps)
            == "com.apple.safari.webapp")
        #expect(WebNotificationSource.isShared("com.apple.Safari.WebApp"))
        #expect(!WebNotificationSource.isShared(own))
    }

    @Test func browserNotificationsAreAttributedBySite() {
        #expect(WebNotificationSource.isShared("app.zen-browser.zen"))
        #expect(WebNotificationSource.isShared("com.google.Chrome"))
        #expect(!WebNotificationSource.isShared("com.automattic.beeper.desktop"))
        #expect(WebNotificationSource.resolvedIdentifier("app.zen-browser.zen", site: "mail.google.com", apps: webApps)
            == webApps[0].identifier)
        #expect(WebNotificationSource.resolvedIdentifier("app.zen-browser.zen", site: nil, apps: webApps) == "app.zen-browser.zen")
    }

    @Test func bannerCloseActionNames() {
        #expect(BannerMatcher.isCloseAction("Name:Close\nTarget:0x0\nSelector:(null)"))
        #expect(BannerMatcher.isCloseAction("Name:Bezárás\nTarget:0x0"))
        #expect(!BannerMatcher.isCloseAction("AXPress"))
        #expect(!BannerMatcher.isCloseAction("Name:Show Details\nTarget:0x0"))
        #expect(BannerMatcher.displayName(ofAction: "Name:Close\nTarget:0x0") == "Close")
    }

    @Test func bannerMatchingUsesTitleOrBody() {
        let titled = notification(title: "Kovács Béla", body: "Ajánlat")
        #expect(BannerMatcher.keys(for: titled) == ["Kovács Béla"])
        #expect(BannerMatcher.matches(text: "Zen, mail.google.com, KOVÁCS BÉLA, Ajánlat", keys: ["Kovács Béla"]))
        #expect(!BannerMatcher.matches(text: "Zen, Nagy Anna, Szia", keys: ["Kovács Béla"]))

        let untitled = notification(title: "", body: "Holnap 9-kor találkozunk a földszinten")
        #expect(BannerMatcher.keys(for: untitled) == ["Holnap 9-kor találkozunk a föl"])
        #expect(BannerMatcher.keys(for: notification(title: "", body: "")).isEmpty)
    }

    /// Spec E-11: the reply goes to the chat named like the notification.
    @Test func beeperChatMatching() {
        let chats = [
            BeeperChat(id: "1", title: "Anna Kovács (work)", unreadCount: 0, lastActivity: nil),
            BeeperChat(id: "2", title: "anna kovács", unreadCount: 0, lastActivity: nil),
            BeeperChat(id: "3", title: "Team", unreadCount: 2, lastActivity: nil)
        ]
        #expect(BeeperClient.bestMatch(for: "Anna Kovács", in: chats)?.id == "2")
        #expect(BeeperClient.bestMatch(for: "Someone else", in: chats)?.id == "3")
        #expect(BeeperClient.bestMatch(for: "x", in: []) == nil)
    }

    @Test @MainActor func unseenNotificationsAndReplyAvailability() {
        let defaults = UserDefaults(suiteName: "DynotchTests-\(UUID().uuidString)") ?? .standard
        let service = NotificationService(settings: AppSettings(defaults: defaults))
        service.present(title: "A", body: "1", appIdentifier: "com.automattic.beeper.desktop")
        service.present(title: "B", body: "2", appIdentifier: "com.apple.btmnotificationagent")
        #expect(service.unseen.map(\.title) == ["A", "B"])
        // The reply field is off by default, for chats and system notices alike (spec E-16b).
        #expect(!service.canReply(to: service.unseen[0]))
        #expect(!service.canReply(to: service.unseen[1]))
        service.markSeen()
        #expect(service.unseen.isEmpty)
        service.clearPeek()
    }

    /// Spec E-7b: "via chat.google.com" and similar source lines are not shown.
    @Test func sourceLinesAreHidden() {
        let chat = NotificationPresenter.content(
            for: notification(title: "Béla", subtitle: "via chat.google.com", body: "Szia!\nvia chat.google.com"),
            appName: "Google Chat", kind: .message
        )
        #expect(chat.detail == "Szia!")

        let beeper = NotificationPresenter.content(
            for: notification(title: "Anna", subtitle: "via WhatsApp", body: "Holnap?"),
            appName: "Beeper Desktop", kind: .message
        )
        #expect(beeper.detail == "Holnap?")

        let gmail = NotificationPresenter.content(
            for: notification(title: "Kovács Béla", subtitle: "via mail.google.com", body: "Ajánlat\nSzia, küldöm…"),
            appName: "Gmail", kind: .mail
        )
        #expect(gmail.detail == "Ajánlat")

        #expect(!NotificationPresenter.isSourceLine("via the office later"))
        #expect(!NotificationPresenter.isSourceLine("Csapat"))
        #expect(NotificationPresenter.isSourceLine("  VIA chat.google.com "))
    }

    /// Spec E-4: hovering shows only that sender's new messages; the others stay new.
    @Test @MainActor func relatedNotificationsAreTheSameSendersOnly() {
        let defaults = UserDefaults(suiteName: "DynotchTests-\(UUID().uuidString)") ?? .standard
        let service = NotificationService(settings: AppSettings(defaults: defaults))
        let beeper = "com.automattic.beeper.desktop"
        service.present(title: "Anna", body: "1", appIdentifier: beeper)
        service.present(title: "Béla", body: "2", appIdentifier: beeper)
        service.present(title: "anna ", body: "3", appIdentifier: beeper)
        service.present(title: "Anna", body: "4", appIdentifier: "com.apple.safari.webapp.x")
        let anna = service.related(to: service.unseen[2])
        #expect(anna.map(\.body) == ["1", "3"])
        service.markSeen(anna)
        #expect(service.unseen.map(\.body) == ["2", "4"])
        service.clearPeek()
    }

    /// Spec E-11b: the conversation address is read from the record, never from the message.
    @Test func conversationLinkFromTheRecord() throws {
        let userInfo = try PropertyListSerialization.data(
            fromPropertyList: ["url": "https://chat.google.com/u/0/app/chat/AAAAbcdEfgh"], format: .binary, options: 0
        )
        let plist: [String: Any] = [
            "app": "app.zen-browser.zen",
            "req": ["titl": "Béla", "body": "see https://chat.google.com/dm/XYZ123456", "usda": userInfo]
        ]
        let link = WebNotificationSource.conversationLink(in: plist)
        #expect(link?.absoluteString == "https://chat.google.com/u/0/app/chat/AAAAbcdEfgh")
        #expect(WebNotificationSource.maskedShape(of: try #require(link)) == "chat.google.com/u/0/app/chat/…")

        let noLink: [String: Any] = ["req": ["titl": "x", "body": "https://chat.google.com/dm/ABCDEF123"]]
        #expect(WebNotificationSource.conversationLink(in: noLink) == nil)
    }

    @Test func conversationLinkShapes() throws {
        #expect(WebNotificationSource.isConversation(try #require(URL(string: "https://mail.google.com/mail/u/0/#chat/dm/abc"))))
        #expect(WebNotificationSource.isConversation(try #require(URL(string: "https://mail.google.com/chat/u/0/#chat/space/x"))))
        #expect(!WebNotificationSource.isConversation(try #require(URL(string: "https://mail.google.com/mail/u/0/#inbox/123"))))
        #expect(!WebNotificationSource.isConversation(try #require(URL(string: "https://example.com/chat"))))
    }

    /// Spec E-2c: System Settings notices are shown by default, with a readable name.
    @Test func systemSettingsNotices() {
        #expect(NotificationApp.systemName(for: "com.apple.btmnotificationagent") == "Login Items")
        #expect(NotificationApp.systemName(for: "_system_center_:com.apple.softwareupdatenotification") == "Software Update")
        #expect(NotificationApp.isDefaultEnabled(identifier: "com.apple.tccd", name: "com.apple.tccd"))
        #expect(!NotificationApp.isDefaultEnabled(identifier: "com.apple.music", name: "Music"))
    }

    /// Spec E-12: one notification can be removed, or all at once.
    @Test @MainActor func removeAndClearAll() {
        let defaults = UserDefaults(suiteName: "DynotchTests-\(UUID().uuidString)") ?? .standard
        let service = NotificationService(settings: AppSettings(defaults: defaults))
        service.present(title: "A", body: "1", appIdentifier: "x")
        service.present(title: "B", body: "2", appIdentifier: "x")
        service.remove(service.recent[0])
        #expect(service.recent.map(\.title) == ["A"])
        #expect(service.unseen.map(\.title) == ["A"])
        service.clearAll()
        #expect(service.recent.isEmpty)
        #expect(service.unseen.isEmpty)
        #expect(service.peek == nil)
    }
}

@MainActor
struct DynotchAlertTests {
    @Test func aKindTurnedOffIsNeitherShownNorListed() throws {
        let defaults = try #require(UserDefaults(suiteName: "DynotchAlertTests-\(UUID().uuidString)"))
        let preferences = NotificationPreferences(defaults: defaults)
        #expect(preferences.isOn(.system))
        preferences.set(.system, isOn: false)
        #expect(!preferences.isOn(.system))
        #expect(preferences.isOn(.aiUsage))
        // Kept across launches.
        #expect(!NotificationPreferences(defaults: defaults).isOn(.system))
        preferences.set(.system, isOn: true)
        #expect(NotificationPreferences(defaults: defaults).isOn(.system))
    }
}
