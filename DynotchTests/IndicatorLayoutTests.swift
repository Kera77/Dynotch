import CoreGraphics
@testable import Dynotch
import Testing

struct IndicatorLayoutTests {
    private let notchRect = CGRect(x: 663.5, y: 950, width: 185, height: 32)

    @Test func widthGrowsWithCount() {
        let notch = notchRect.size
        #expect(IndicatorLayout(count: 0).size(notch: notch, showsLabel: false) == notch)
        #expect(IndicatorLayout(count: 1).sideWidth == IndicatorLayout.minimumSideWidth)
        #expect(IndicatorLayout(count: 2).sideWidth > IndicatorLayout(count: 1).sideWidth)
        let withLabel = IndicatorLayout(count: 1).size(notch: notch, showsLabel: true)
        #expect(withLabel.height == notch.height + IndicatorLayout.labelHeight)
        #expect(withLabel.width >= IndicatorLayout.labelWidth)
    }

    @Test func hoverFindsSlotOnBothSides() {
        let layout = IndicatorLayout(count: 2)
        for index in 0..<2 {
            let centers = layout.centers(of: index, notchRect: notchRect)
            #expect(layout.slot(at: CGPoint(x: centers.right, y: notchRect.midY), notchRect: notchRect) == index)
            #expect(layout.slot(at: CGPoint(x: centers.left, y: notchRect.midY), notchRect: notchRect) == index)
        }
        #expect(layout.slot(at: CGPoint(x: notchRect.midX, y: notchRect.midY), notchRect: notchRect) == nil)
        let right = layout.centers(of: 0, notchRect: notchRect).right
        #expect(layout.slot(at: CGPoint(x: right, y: notchRect.minY - 10), notchRect: notchRect) == nil)
        #expect(layout.slot(at: CGPoint(x: right, y: notchRect.maxY), notchRect: notchRect) == 0)
    }

    @Test func slotsStayInsideTheWidenedNotch() {
        for count in 1...3 {
            let layout = IndicatorLayout(count: count)
            let last = layout.centers(of: count - 1, notchRect: notchRect)
            #expect(last.right + IndicatorLayout.slotWidth / 2 <= notchRect.maxX + layout.sideWidth)
            #expect(last.left - IndicatorLayout.slotWidth / 2 >= notchRect.minX - layout.sideWidth)
        }
    }
}
