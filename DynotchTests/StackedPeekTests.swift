@testable import Dynotch
import Foundation
import SwiftUI
import Testing

/// Black over glass, the drop-down notices' design, two notices under the notch, the web Teams'
/// tabs and badge (spec D-24, D-25, E-28, MT-13, B-15).
@MainActor
struct StackedPeekTests {
    private func note(_ id: Int64, _ sender: String, app: String = "com.apple.MobileSMS") -> AppNotification {
        AppNotification(id: id, appIdentifier: app, title: sender, subtitle: "", body: "Hi", date: Date())
    }

    @Test func aNewSenderGoesOnTopAndTheEarlierOneMovesUnder() {
        let now = Date()
        let anna = note(1, "Anna"), ben = note(2, "Ben")
        let stack = NotificationService.stacked(top: (anna, now + 4), second: nil, new: ben, now: now, duration: 6)
        #expect(stack.top.0 == ben)
        #expect(stack.second?.0 == anna)
        // The earlier one keeps its own time.
        #expect(stack.second?.1 == now + 4)
    }

    @Test func theSameSenderReplacesItsRowAndAtMostTwoStay() {
        let now = Date()
        let anna = note(1, "Anna"), ben = note(2, "Ben"), anna2 = note(3, "Anna"), cleo = note(4, "Cleo")
        let same = NotificationService.stacked(top: (anna, now + 4), second: nil, new: anna2, now: now, duration: 6)
        #expect(same.second == nil)
        let three = NotificationService.stacked(top: (ben, now + 5), second: (anna, now + 3), new: cleo, now: now, duration: 6)
        #expect(three.top.0 == cleo)
        #expect(three.second?.0 == ben)
        let expired = NotificationService.stacked(top: (ben, now - 1), second: nil, new: cleo, now: now, duration: 6)
        #expect(expired.second == nil)
    }

    @Test func peekDesignsKeepABlackTopWithTheirOwnFade() {
        #expect(DesignBackground<Rectangle>.topFade(design: .black, isPeek: true) == nil)
        #expect(DesignBackground<Rectangle>.topFade(design: .glass, isPeek: false) == nil)
        #expect(DesignBackground<Rectangle>.topFade(design: .glass, isPeek: true) == 12)
        #expect(DesignBackground<Rectangle>.topFade(design: .blend, isPeek: false) == 80)
        #expect(DesignBackground<Rectangle>.topFade(design: .blend, isPeek: true) == 20)
        #expect(DesignBackground<Rectangle>.topFade(design: .split, isPeek: false) == 0)
        let sharp = DesignBackground<Rectangle>.blackTopStops(height: 200, topRow: 38, fade: 0)
        #expect(sharp.count == 4)
        #expect(sharp[1].location == sharp[2].location)
    }

    @Test func teamsTabsAreReadWithTextWindowIDs() {
        let text = "w-abc-1\t10\tfalse\thttps://teams.live.com/v2/\t(3) Teams\n12\t2\ttrue\thttps://example.com/\tOther\n"
        let tabs = TeamsTabs.parse(text)
        #expect(tabs.count == 1)
        #expect(tabs.first?.windowID == "w-abc-1")
        #expect(tabs.first?.isActive == false)
        #expect(TeamsTabs.unread(in: tabs) == 3)
        #expect(TeamsTabs.parse("w\"x\t1\tfalse\thttps://teams.live.com/\tTeams").isEmpty)
    }

    @Test func theWebTeamsBadgeCountsItsTab() {
        #expect(BrowserTabBadges.site(forBadgeName: TeamsWebBadge.name) == BrowserTabBadges.teamsSite)
        #expect(BrowserTabBadges.site(forBadgeName: "Microsoft Teams") == nil)
        let counts = BrowserTabBadges.counts(from: [.init(url: "https://teams.cloud.microsoft/", title: "(2) Chat | Teams")])
        #expect(counts[BrowserTabBadges.teamsSite] == 2)
        let badge = BadgeApp(bundleID: TeamsWebBadge.id, name: TeamsWebBadge.name, isEnabled: true, icon: .app)
        #expect(BadgeApp.chatTab(for: badge) == .teams)
    }
}
