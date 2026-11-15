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

    /// Regression: pushing the pointer to the very top edge opened the panel and then closed it,
    /// because the expanded rect excluded y == screen.maxY.
    @Test func pointerOnTopEdgeKeepsPanelOpen() {
        let geometry = NotchGeometry.make(
            screenFrame: screen, safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        let topEdge = CGPoint(x: screen.midX, y: screen.maxY)
        #expect(geometry.hoverZone.contains(topEdge))
        #expect(geometry.expandedHoverZone.contains(topEdge))

        let topEdgeNearPanelSide = CGPoint(x: geometry.expandedRect.minX + 1, y: screen.maxY)
        #expect(geometry.expandedHoverZone.contains(topEdgeNearPanelSide))
        #expect(!geometry.expandedHoverZone.contains(CGPoint(x: geometry.expandedRect.minX - 1, y: screen.maxY)))
    }

    @Test func largePanelFitsScreenAndStaysOpenOnTopEdge() {
        let small = CGRect(x: 0, y: 0, width: 800, height: 600)
        for frame in [screen, small] {
            let geometry = NotchGeometry.make(
                screenFrame: frame, safeAreaTop: 0,
                auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil, menuBarHeight: 24
            )
            let large = geometry.rect(for: geometry.largeSize)
            #expect(frame.contains(large))
            #expect(large.width >= geometry.expandedSize.width)
            #expect(large.contains(geometry.expandedRect))
            #expect(geometry.keepOpenZone(for: geometry.largeSize).contains(CGPoint(x: large.minX + 1, y: frame.maxY)))
        }
    }

    @Test func dayStripZoneIsBelowMenuBarInsidePanel() {
        let geometry = NotchGeometry.make(
            screenFrame: screen, safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        let strip = geometry.dayStripZone
        #expect(geometry.expandedRect.contains(strip))
        #expect(strip.maxY == screen.maxY - geometry.menuBarHeight)
        #expect(strip.height == NotchGeometry.dayStripHeight)
        #expect(!strip.intersects(geometry.notchRect))
    }

    @Test func windowFitsEveryPanelSize() {
        let geometry = NotchGeometry.make(
            screenFrame: screen, safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        let window = geometry.rect(for: geometry.windowSize)
        for size in [geometry.expandedSize, geometry.largeSize, geometry.settingsSize, geometry.peekSize] {
            #expect(window.contains(geometry.rect(for: size)))
        }
        #expect(geometry.settingsSize.width >= NotchGeometry.settingsContentSize.width)
        #expect(geometry.settingsSize.height >= geometry.menuBarHeight + NotchGeometry.settingsContentSize.height)
    }
}
