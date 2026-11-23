import CoreGraphics
@testable import Dynotch
import Testing

/// Spec B-2b: unread counts from Ardia's tab titles; F-14b: large floating windows.
struct BrowserTabBadgeTests {
    private typealias Tab = BrowserTabBadges.Tab

    @Test func gmailInboxTitleCounts() {
        let tabs = [
            Tab(url: "https://mail.google.com/mail/u/1/#inbox", title: "Beérkező levelek (9) - x - Mail"),
            Tab(url: "https://mail.google.com/mail/u/1/#inbox", title: "Beérkező levelek (9) - x - Mail"),
            Tab(url: "https://mail.google.com/mail/u/0/#inbox", title: "Inbox (3) - y - Gmail")
        ]
        #expect(BrowserTabBadges.counts(from: tabs)[BrowserTabBadges.gmailSite] == 12)
    }

    @Test func titleWithoutNumber() {
        let tabs = [
            Tab(url: "https://chat.google.com/u/1/app/home", title: "Csevegés"),
            Tab(url: "https://mail.google.com/mail/u/0/#sent", title: "Elküldött - y - Gmail")
        ]
        let counts = BrowserTabBadges.counts(from: tabs)
        #expect(counts[BrowserTabBadges.chatSite] == 0)
        #expect(counts[BrowserTabBadges.gmailSite] == nil)
    }

    @Test func parsingAndNames() {
        let tabs = BrowserTabBadges.parse("https://chat.google.com/u/0\tChat (2)\nbroken\n")
        #expect(BrowserTabBadges.counts(from: tabs)[BrowserTabBadges.chatSite] == 2)
        #expect(BrowserTabBadges.site(forBadgeName: "Gmail") == BrowserTabBadges.gmailSite)
        #expect(BrowserTabBadges.site(forBadgeName: "Google Chat") == BrowserTabBadges.chatSite)
        #expect(BrowserTabBadges.site(forBadgeName: "ChatGPT") == nil)
    }

    @Test func largeFloatingWindowIsNormal() {
        #expect(FocusRules.isNormalWindow(subrole: "AXStandardWindow", size: CGSize(width: 50, height: 50)))
        #expect(FocusRules.isNormalWindow(subrole: "AXSystemFloatingWindow", size: CGSize(width: 823, height: 1410)))
        #expect(!FocusRules.isNormalWindow(subrole: "AXSystemFloatingWindow", size: CGSize(width: 250, height: 150)))
        #expect(!FocusRules.isNormalWindow(subrole: "AXUnknown", size: CGSize(width: 800, height: 800)))
    }

    @Test func focusLeavesLargeFloatingWindow() {
        #expect(!FocusRules.focusedKeepsFocus(subrole: "AXSystemFloatingWindow", size: CGSize(width: 823, height: 1410)))
        #expect(!FocusRules.focusedKeepsFocus(subrole: "AXStandardWindow", size: .zero))
        #expect(FocusRules.focusedKeepsFocus(subrole: "AXSystemFloatingWindow", size: CGSize(width: 250, height: 150)))
        #expect(FocusRules.focusedKeepsFocus(subrole: "AXDialog", size: CGSize(width: 800, height: 600)))
        #expect(FocusRules.focusedKeepsFocus(subrole: "AXUnknown", size: CGSize(width: 800, height: 800)))
    }
}
