import CoreGraphics
@testable import Dynotch
import Testing

/// v0.35: the controls right of the notch fit beside it, the tablet menu among them (spec TB-1).
struct V035Tests {
    @Test func theRightControlsFitBesideEveryNotch() {
        for notchWidth in [CGFloat(160), 185, 200, 240] {
            let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
            let side = (screen.width - notchWidth) / 2
            let geometry = NotchGeometry.make(
                screenFrame: screen, safeAreaTop: 32, auxiliaryLeftWidth: side, auxiliaryRightWidth: side, menuBarHeight: 32
            )
            let room = (geometry.expandedSize.width - geometry.notchSize.width) / 2
            #expect(TrailingControlsMetrics.width <= room)
        }
    }

    @Test func noFocusChangeRightAfterAClick() {
        #expect(FocusRules.quietAfterClick >= 0.3)
    }
}
