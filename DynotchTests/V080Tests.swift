@testable import Dynotch
import Foundation
import Testing

@MainActor
struct V080Tests {
    private let limits = [UsageLimit(id: "five_hour", title: "Session", utilization: 82, resetsAt: Date().addingTimeInterval(3600))]

    /// PV-58: in Wings mode the hovered AI ring widens sideways, nothing drops down.
    @Test func usageUnfoldsSidewaysInWings() {
        let items = IndicatorItem.items(meetings: [], usage: limits)
        let unfolded = IndicatorItem.unfoldingUsage(items, hovered: 0, wings: true)
        #expect(unfolded[0].labelHeight == 0)
        #expect(unfolded[0].slotWidth > items[0].slotWidth + 40)
        #expect(unfolded[0].id == items[0].id)
        let layout = IndicatorLayout(items: unfolded)
        let notch = CGSize(width: 200, height: 32)
        #expect(layout.size(notch: notch, labelHeight: 0).height == notch.height)
    }

    /// PV-58: without Wings (or without hover) it drops its details down as before.
    @Test func usageDropsDownOutsideWings() {
        let items = IndicatorItem.items(meetings: [], usage: limits)
        #expect(IndicatorItem.unfoldingUsage(items, hovered: 0, wings: false) == items)
        #expect(IndicatorItem.unfoldingUsage(items, hovered: nil, wings: true) == items)
        #expect(items[0].labelHeight > 0)
    }

    @Test func resetTextNamesTheTime() {
        let text = IndicatorItem.usageResetText(limits)
        #expect(text.hasPrefix("Resets today") || text.hasPrefix("Resets tomorrow"))
    }
}
