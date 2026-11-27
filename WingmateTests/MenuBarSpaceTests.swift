import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

/// Spec B-8: badges never cover the menu bar's own items.
@MainActor
struct MenuBarSpaceTests {
    private func badge(_ id: String) -> BadgeItem {
        BadgeItem(app: BadgeApp(bundleID: id, name: id, isEnabled: true, icon: .app), label: "3", pulseStart: nil)
    }

    // Two displays side by side: the main one (1512 wide) and one on its right (2560 wide).
    private let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let external = CGRect(x: 1512, y: -458, width: 2560, height: 1440)

    @Test func menusAreMeasuredOnEveryDisplay() {
        // "Help" ends 600 points from the main display's left edge (top-left coordinates).
        let snapshot = MenuBarSnapshot(menuItems: [
            CGRect(x: 10, y: 0, width: 40, height: 24), CGRect(x: 550, y: 0, width: 50, height: 24)
        ])
        let edge = MenuBarSpace.occupiedEdge(
            on: external, screens: [main, external], primaryMaxY: main.maxY, notchMinX: 1512 + 1187, snapshot: snapshot
        )
        #expect(abs((edge ?? 0) - (1512 + 600)) < 0.001)
        let room = MenuBarSpace.room(notchMinX: 1512 + 1187, occupiedEdge: edge)
        #expect(abs((room ?? 0) - (1187 - 600 - MenuBarSpace.gap)) < 0.001)
        // Nothing left of the notch: no limit.
        let empty = MenuBarSpace.occupiedEdge(
            on: main, screens: [main], primaryMaxY: main.maxY, notchMinX: 663, snapshot: MenuBarSnapshot()
        )
        #expect(empty == nil)
        #expect(MenuBarSpace.room(notchMinX: 663, occupiedEdge: nil) == nil)
    }

    @Test func statusItemsCountOnlyOnTheirDisplayAndLeftOfTheNotch() {
        let snapshot = MenuBarSnapshot(statusItems: [
            CGRect(x: 500, y: 0, width: 30, height: 24),
            CGRect(x: 900, y: 0, width: 30, height: 24)
        ])
        let edge = MenuBarSpace.occupiedEdge(
            on: main, screens: [main, external], primaryMaxY: main.maxY, notchMinX: 663, snapshot: snapshot
        )
        #expect(abs((edge ?? 0) - 530) < 0.001)
        let other = MenuBarSpace.occupiedEdge(
            on: external, screens: [main, external], primaryMaxY: main.maxY, notchMinX: 2699, snapshot: snapshot
        )
        #expect(other == nil)
    }

    @Test func onlyTheBadgesThatFitAreShownWithAPlus() {
        let all = ["a", "b", "c", "d"].map(badge)
        let items = [IndicatorItem.working]
        let full = IndicatorLayout(items: items, badges: all).leftWidth

        #expect(BadgeFit.make(badges: all, items: items, room: nil, unfolded: false) == BadgeFit(shown: all, hidden: 0))
        #expect(BadgeFit.make(badges: all, items: items, room: full, unfolded: false).hidden == 0)

        let tight = BadgeFit.make(badges: all, items: items, room: full - 1, unfolded: false)
        #expect(tight.hidden > 0)
        #expect(tight.shown + Array(all.dropFirst(tight.shown.count)) == all)
        #expect(IndicatorLayout(items: items, badges: tight.shown, overflow: true).leftWidth <= full - 1)
        // Hovering the "+" shows them all.
        #expect(BadgeFit.make(badges: all, items: items, room: full - 1, unfolded: true).hidden == 0)
        // No room at all: only the "+".
        #expect(BadgeFit.make(badges: all, items: items, room: 0, unfolded: false) == BadgeFit(shown: [], hidden: 4))
    }

    @Test func thePlusSitsLeftOfTheBadges() {
        let notch = CGRect(x: 663, y: 950, width: 186, height: 32)
        let layout = IndicatorLayout(slotWidths: [IndicatorLayout.ringSlotWidth], badgeWidths: [28], overflow: true)
        let plus = layout.overflowRange(notchRect: notch)
        let first = layout.badgeRange(0, notchRect: notch)
        #expect((plus?.upperBound ?? .infinity) < first.lowerBound)
        #expect(layout.leftRange(notchRect: notch)?.upperBound == notch.minX)
        #expect(IndicatorLayout(slotWidths: [], badgeWidths: [], overflow: false).overflowRange(notchRect: notch) == nil)
    }
}
