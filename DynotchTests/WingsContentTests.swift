@testable import Dynotch
import Foundation
import Testing

@MainActor
struct WingsContentTests {
    private let geometry = NotchGeometry.make(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
        auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
    )

    @Test func wingsWidenToTheDisplayAndGrowByTheDropDown() {
        let plain = geometry.wingsSize(side: 200, state: WingsState())
        #expect(plain == geometry.previewSize(side: 200))
        #expect(plain.width <= 1512 * 2 / 3)
        var state = WingsState()
        state.isWide = true
        state.dropHeight = 120
        let wide = geometry.wingsSize(side: 200, state: state)
        #expect(wide.width == geometry.maxModuleSize.width)
        #expect(wide.height == plain.height + 120)
        state.closeDrop()
        #expect(state.dropHeight == 0 && !state.isOnDrop)
    }

    @Test func roomForDevicesStaysInsideTwoThirds() {
        let content = geometry.wingsMaxContent
        #expect(content > 0)
        #expect(geometry.notchSize.width + 2 * (content + 2 * WingsLayout.padding) <= 1512 * 2 / 3 + 0.5)
    }

    @Test func noteBodyStartsOnTheSecondLine() {
        #expect(NotchView.noteBody("Title\n\nFirst line\n  Second  \n") == "First line · Second")
        #expect(NotchView.noteBody("Only a title").isEmpty)
    }
}
