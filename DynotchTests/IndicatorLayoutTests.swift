import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

struct IndicatorLayoutTests {
    private let notchRect = CGRect(x: 663.5, y: 950, width: 185, height: 32)

    @Test func leftSideOnlyReachesTheIcon() {
        let notch = notchRect.size
        #expect(IndicatorLayout(count: 0).size(notch: notch, labelHeight: nil) == notch)
        for count in 1...3 {
            let layout = IndicatorLayout(count: count)
            #expect(layout.leftWidth == IndicatorLayout.iconWidth + 2 * IndicatorLayout.padding)
            #expect(layout.rightWidth > layout.leftWidth)
        }
        #expect(IndicatorLayout(count: 2).rightWidth > IndicatorLayout(count: 1).rightWidth)
        let withLabel = IndicatorLayout(count: 1).size(notch: notch, labelHeight: IndicatorLayout.labelHeight)
        #expect(withLabel.height == notch.height + IndicatorLayout.labelHeight)
        #expect(withLabel.width >= IndicatorLayout.labelWidth)
    }

    /// Spec K-7: the asymmetric black area keeps the physical notch in place.
    @Test func blackAreaKeepsTheNotchInPlace() {
        for count in 1...3 {
            let layout = IndicatorLayout(count: count)
            let rect = layout.rect(notchRect: notchRect, labelHeight: nil)
            #expect(abs((notchRect.minX - rect.minX) - layout.leftWidth) < 0.001)
            #expect(abs((rect.maxX - notchRect.maxX) - layout.rightWidth) < 0.001)
            #expect(rect.maxY == notchRect.maxY)
            let labelled = layout.rect(notchRect: notchRect, labelHeight: IndicatorLayout.labelHeight)
            #expect(abs(labelled.midX - rect.midX) < 0.001)
            #expect(labelled.contains(rect))
        }
    }

    @Test func hoverFindsCountdownsAndTheIcon() {
        let layout = IndicatorLayout(count: 2)
        for index in 0..<2 {
            let center = layout.center(of: index, notchRect: notchRect)
            #expect(layout.slot(at: CGPoint(x: center, y: notchRect.midY), notchRect: notchRect) == index)
        }
        let icon = CGPoint(x: layout.iconCenter(notchRect: notchRect), y: notchRect.midY)
        #expect(layout.slot(at: icon, notchRect: notchRect) == 0)
        #expect(layout.slot(at: CGPoint(x: notchRect.minX - layout.leftWidth - 5, y: notchRect.midY), notchRect: notchRect) == nil)
        #expect(layout.slot(at: CGPoint(x: notchRect.midX, y: notchRect.midY), notchRect: notchRect) == nil)
        let right = layout.center(of: 0, notchRect: notchRect)
        #expect(layout.slot(at: CGPoint(x: right, y: notchRect.minY - 10), notchRect: notchRect) == nil)
        #expect(layout.slot(at: CGPoint(x: right, y: notchRect.maxY), notchRect: notchRect) == 0)
    }

    @Test func countdownsStayInsideTheBlackArea() {
        for count in 1...3 {
            let layout = IndicatorLayout(count: count)
            let rect = layout.rect(notchRect: notchRect, labelHeight: nil)
            #expect(layout.center(of: count - 1, notchRect: notchRect) + IndicatorLayout.slotWidth / 2 <= rect.maxX)
            #expect(layout.iconCenter(notchRect: notchRect) - IndicatorLayout.iconWidth / 2 >= rect.minX)
        }
    }

    /// Spec CL-6: the Claude usage sits after the meetings, with its own icon on the left.
    @Test func claudeUsageHasItsOwnIconAndCapsule() {
        let event = CalendarEvent(id: "m", title: "M", start: Date(), end: Date().addingTimeInterval(600),
                                  isAllDay: false, color: .fallback, meetingURL: nil)
        let usage = [UsageLimit(id: "five_hour", title: "Session", utilization: 72, resetsAt: nil)]
        let items = IndicatorItem.items(meetings: [event, event], usage: usage)
        #expect(items.count == 3)
        #expect(IndicatorItem.iconSlots(for: items) == [0, 2])

        let layout = IndicatorLayout(items: items)
        #expect(layout.leftWidth == 2 * IndicatorLayout.iconWidth + IndicatorLayout.spacing + 2 * IndicatorLayout.padding)
        let claudeIcon = CGPoint(x: layout.iconCenter(1, notchRect: notchRect), y: notchRect.midY)
        #expect(layout.slot(at: claudeIcon, notchRect: notchRect) == 2)
        let meetingIcon = CGPoint(x: layout.iconCenter(0, notchRect: notchRect), y: notchRect.midY)
        #expect(layout.slot(at: meetingIcon, notchRect: notchRect) == 0)
        #expect(layout.slot(at: CGPoint(x: layout.center(of: 2, notchRect: notchRect), y: notchRect.midY), notchRect: notchRect) == 2)

        let onlyUsage = IndicatorItem.items(meetings: [], usage: usage)
        #expect(IndicatorItem.iconSlots(for: onlyUsage) == [0])
        #expect(onlyUsage[0].labelHeight > IndicatorLayout.labelHeight - 1)
    }

    /// Spec CL-6: the AI usage is a narrow ring; places are laid out by their own widths.
    @Test func usageRingIsNarrowAndHitTestedByWidth() {
        let event = CalendarEvent(id: "m", title: "M", start: Date(), end: Date().addingTimeInterval(600),
                                  isAllDay: false, color: .fallback, meetingURL: nil)
        let usage = [UsageLimit(id: "session", title: "Session", utilization: 84, resetsAt: nil)]
        let layout = IndicatorLayout(items: IndicatorItem.items(meetings: [event], usage: usage))
        #expect(layout.slotWidths == [IndicatorLayout.slotWidth, IndicatorLayout.ringSlotWidth])
        #expect(layout.rightWidth == IndicatorLayout.slotWidth + IndicatorLayout.ringSlotWidth
            + IndicatorLayout.spacing + 2 * IndicatorLayout.padding)
        let ring = layout.center(of: 1, notchRect: notchRect)
        #expect(ring - layout.center(of: 0, notchRect: notchRect)
            == (IndicatorLayout.slotWidth + IndicatorLayout.ringSlotWidth) / 2 + IndicatorLayout.spacing)
        #expect(layout.slot(at: CGPoint(x: ring, y: notchRect.midY), notchRect: notchRect) == 1)
        #expect(layout.slot(at: CGPoint(x: ring + 20, y: notchRect.midY), notchRect: notchRect) == nil)
    }

    /// Even widths keep the row beside the notch on whole pixels.
    @MainActor @Test func widthsBesideTheNotchAreEven() {
        let widths: [CGFloat] = [
            NotchGeometry.virtualNotchWidth, IndicatorLayout.slotWidth, IndicatorLayout.ringSlotWidth,
            IndicatorLayout.batterySlotWidth, IndicatorLayout.iconWidth, IndicatorLayout.spacing, IndicatorLayout.padding,
            IndicatorLayout.separatorWidth, IndicatorLayout.badgeSpacing, LevelRing.size,
            BatteryItemWidths.one, BatteryItemWidths.three
        ]
        #expect(widths.allSatisfy { $0.truncatingRemainder(dividingBy: 2) == 0 })
        let layout = IndicatorLayout(
            slotWidths: [IndicatorLayout.slotWidth, IndicatorLayout.ringSlotWidth], badgeWidths: [BatteryItemWidths.one]
        )
        #expect(layout.horizontalOffset == layout.horizontalOffset.rounded())
    }

    private enum BatteryItemWidths {
        static let one = BadgeItem.width(text: "7")
        static let three = BadgeItem.width(text: "99+")
    }

    private let limits = [UsageLimit(id: "five_hour", title: "Session", utilization: 82, resetsAt: Date().addingTimeInterval(3600))]

    /// PV-58: in Wings mode the hovered AI ring widens sideways, nothing drops down.
    @MainActor @Test func usageUnfoldsSidewaysInWings() {
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
    @MainActor @Test func usageDropsDownOutsideWings() {
        let items = IndicatorItem.items(meetings: [], usage: limits)
        #expect(IndicatorItem.unfoldingUsage(items, hovered: 0, wings: false) == items)
        #expect(IndicatorItem.unfoldingUsage(items, hovered: nil, wings: true) == items)
        #expect(items[0].labelHeight > 0)
    }

    @MainActor @Test func resetTextNamesTheTime() {
        let text = IndicatorItem.usageResetText(limits)
        #expect(text.hasPrefix("Resets today") || text.hasPrefix("Resets tomorrow"))
    }
}
