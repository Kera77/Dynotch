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
}
