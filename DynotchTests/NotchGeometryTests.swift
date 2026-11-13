import CoreGraphics
@testable import Dynotch
import Testing

struct NotchGeometryTests {
    // 14" MacBook Pro: 1512 × 982 pt, notch ≈ 185 × 32 pt
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func physicalNotchIsMeasuredFromAuxiliaryAreas() {
        let geometry = NotchGeometry.make(
            screenFrame: screen, safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        #expect(geometry.hasPhysicalNotch)
        #expect(geometry.notchSize == CGSize(width: 185, height: 32))
        #expect(geometry.notchRect.midX == screen.midX)
        #expect(geometry.notchRect.maxY == screen.maxY)
    }

    @Test func screenWithoutNotchGetsVirtualNotch() {
        let geometry = NotchGeometry.make(
            screenFrame: screen, safeAreaTop: 0,
            auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil, menuBarHeight: 24
        )
        #expect(!geometry.hasPhysicalNotch)
        #expect(geometry.notchSize == CGSize(width: NotchGeometry.virtualNotchWidth, height: 24))
    }

    @Test func expandedPanelIsTopCenteredAndWiderThanNotch() {
        let geometry = NotchGeometry.make(
            screenFrame: screen, safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        let rect = geometry.expandedRect
        #expect(rect.maxY == screen.maxY)
        #expect(abs(rect.midX - screen.midX) <= 0.5)
        #expect(rect.contains(geometry.notchRect))
        #expect(rect.width >= NotchGeometry.minimumExpandedWidth)
    }

    @Test func hoverZoneReachesTopEdgeOfSecondaryScreen() {
        let secondary = CGRect(x: 1512, y: -200, width: 1920, height: 1080)
        let geometry = NotchGeometry.make(
            screenFrame: secondary, safeAreaTop: 0,
            auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil, menuBarHeight: 25
        )
        let topCenter = CGPoint(x: secondary.midX, y: secondary.maxY - 0.5)
        #expect(geometry.hoverZone.contains(topCenter))
        #expect(!geometry.hoverZone.contains(CGPoint(x: secondary.midX, y: secondary.maxY - 60)))
    }
}
