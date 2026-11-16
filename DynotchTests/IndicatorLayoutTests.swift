import CoreGraphics
@testable import Dynotch
import Testing

struct IndicatorLayoutTests {
    private let notchRect = CGRect(x: 663.5, y: 950, width: 185, height: 32)

    @Test func leftSideOnlyReachesTheIcon() {
        let notch = notchRect.size
        #expect(IndicatorLayout(count: 0).size(notch: notch, showsLabel: false) == notch)
        for count in 1...3 {
            let layout = IndicatorLayout(count: count)
            #expect(layout.leftWidth == IndicatorLayout.iconWidth + 2 * IndicatorLayout.padding)
            #expect(layout.rightWidth > layout.leftWidth)
        }
        #expect(IndicatorLayout(count: 2).rightWidth > IndicatorLayout(count: 1).rightWidth)
        let withLabel = IndicatorLayout(count: 1).size(notch: notch, showsLabel: true)
        #expect(withLabel.height == notch.height + IndicatorLayout.labelHeight)
        #expect(withLabel.width >= IndicatorLayout.labelWidth)
    }

    /// Spec K-7: the asymmetric black area keeps the physical notch in place.
    @Test func blackAreaKeepsTheNotchInPlace() {
        for count in 1...3 {
            let layout = IndicatorLayout(count: count)
            let rect = layout.rect(notchRect: notchRect, showsLabel: false)
            #expect(abs((notchRect.minX - rect.minX) - layout.leftWidth) < 0.001)
            #expect(abs((rect.maxX - notchRect.maxX) - layout.rightWidth) < 0.001)
            #expect(rect.maxY == notchRect.maxY)
            let labelled = layout.rect(notchRect: notchRect, showsLabel: true)
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
            let rect = layout.rect(notchRect: notchRect, showsLabel: false)
            #expect(layout.center(of: count - 1, notchRect: notchRect) + IndicatorLayout.slotWidth / 2 <= rect.maxX)
            #expect(layout.iconCenter(notchRect: notchRect) - IndicatorLayout.iconWidth / 2 >= rect.minX)
        }
    }
}
