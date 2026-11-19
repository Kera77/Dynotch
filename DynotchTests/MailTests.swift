@testable import Dynotch
import Foundation
import Testing

/// Reading Apple Mail's unread messages (spec GM-2…GM-4).
struct MailTests {
    @Test func parsesAccountsNewestFirst() throws {
        let json = """
        [{"name":"Gmail","server":"imap.gmail.com","addresses":[],"unread":7,
          "messages":[{"id":"<a@x>","sender":"Anna Kovács <anna@example.com>","subject":"Hi","date":1000},
                      {"id":"<b@x>","sender":"bob@example.com","subject":"","date":5000}]},
         {"name":"Work","server":"mail.example.com","addresses":["me@example.com"],"unread":0,"messages":[]}]
        """
        let accounts = try #require(MailParser.accounts(from: Data(json.utf8)))
        #expect(accounts.count == 2)
        #expect(accounts[0].isGmail)
        #expect(!accounts[1].isGmail)
        #expect(accounts[0].unread == 7)
        #expect(accounts[0].more == 5)
        #expect(accounts[0].messages.map(\.id) == ["b@x", "a@x"])
        #expect(accounts[0].messages[1].sender == "Anna Kovács")
        #expect(accounts[0].messages[0].sender == "bob@example.com")
    }

    @Test func recognizesGmail() {
        #expect(MailParser.isGmail(server: "", addresses: ["Someone@Gmail.com"]))
        #expect(MailParser.isGmail(server: "imap.googlemail.com", addresses: []))
        #expect(!MailParser.isGmail(server: "imap.mail.me.com", addresses: ["me@icloud.com"]))
        #expect(MailParser.accounts(from: Data("nope".utf8)) == nil)
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
