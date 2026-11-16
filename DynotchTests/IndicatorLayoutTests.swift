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
}
