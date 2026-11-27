import Foundation
import Testing
@testable import Wingmate

/// Reading Apple Mail's unread messages (spec GM-2…GM-4).
struct MailTests {
    @Test func parsesAccountsAndSkipsDisabled() throws {
        let (unit, rec) = ("\u{1F}", "\u{1E}")
        let text = ["ID-1", "Gmail", "imap.gmail.com", "", "true"].joined(separator: unit)
            + rec + ["ID-2", "Work", "mail.example.com", "me@example.com", "true"].joined(separator: unit)
            + rec + ["ID-3", "Old", "mail.example.com", "", "false"].joined(separator: unit) + "\n"
        let infos = try #require(MailParser.accountInfos(from: Data(text.utf8)))
        #expect(infos.map(\.id) == ["ID-1", "ID-2"])
        #expect(infos[0].isGmail)
        #expect(!infos[1].isGmail)
        #expect(MailParser.accountInfos(from: Data()) == [])
        #expect(MailParser.accountInfos(from: Data("nope".utf8)) == nil)
    }

    @Test func buildsAccountNewestFirst() {
        let info = MailAccountInfo(id: "ID-1", name: "Gmail", isGmail: true)
        let rows = [
            MailRow(messageID: "<a@x>", address: "anna@example.com", displayName: "Anna Kovács", subject: "Hi", received: 1_700_000_000),
            MailRow(messageID: "<b@x>", address: "bob@example.com", displayName: "", subject: "", received: 1_700_000_500)
        ]
        let account = MailParser.account(info, unread: 7, rows: rows)
        #expect(account.unread == 7)
        #expect(account.more == 5)
        #expect(account.messages.map(\.id) == ["b@x", "a@x"])
        #expect(account.messages[0].sender == "bob@example.com")
        #expect(account.messages[1].sender == "Anna Kovács")
        #expect(MailParser.date(received: 800_000_000) == Date(timeIntervalSinceReferenceDate: 800_000_000))
    }

    @Test func findsInboxes() {
        #expect(MailParser.inboxAccount(url: "imap://ABC-1/INBOX") == "ABC-1")
        #expect(MailParser.inboxAccount(url: "ews://ABC-2/Inbox") == "ABC-2")
        #expect(MailParser.inboxAccount(url: "imap://ABC-1/%5BGmail%5D/All%20Mail") == nil)
        #expect(MailParser.inboxAccount(url: "imap://ABC-1/Archive/INBOX") == nil)
        // A Gmail label's mailbox, also nested (spec GM-16).
        #expect(MailParser.labelAccount(url: "imap://ABC-1/Primary", label: "primary") == "ABC-1")
        #expect(MailParser.labelAccount(url: "imap://ABC-1/Wingmate%2FPrimary", label: "Wingmate/Primary") == "ABC-1")
        #expect(MailParser.labelAccount(url: "imap://ABC-1/Work/Primary", label: "Work/Primary") == "ABC-1")
        #expect(MailParser.labelAccount(url: "imap://ABC-1/INBOX", label: "Primary") == nil)
        #expect(MailParser.labelAccount(url: "imap://ABC-1/Primary", label: " ") == nil)
    }

    @Test func recognizesGmail() {
        #expect(MailParser.isGmail(server: "", addresses: ["Someone@Gmail.com"]))
        #expect(MailParser.isGmail(server: "imap.googlemail.com", addresses: []))
        #expect(!MailParser.isGmail(server: "imap.mail.me.com", addresses: ["me@icloud.com"]))
    }

    @Test func mailTabOnlyWithMailSource() {
        #expect(NotificationsTab.shown(mail: true).contains(.mail))
        #expect(!NotificationsTab.shown(mail: false).contains(.mail))
    }

    @Test func countdown() {
        let now = Date()
        #expect(WingFormat.countdown(to: now.addingTimeInterval(25 * 60), end: now.addingTimeInterval(3600), now: now) == "in 25 min")
        #expect(WingFormat.countdown(to: now.addingTimeInterval(-60), end: now.addingTimeInterval(60), now: now) == "now")
        #expect(WingFormat.countdown(to: now.addingTimeInterval(3 * 3600), end: now.addingTimeInterval(4 * 3600), now: now) == "in 3 h")
    }
}
