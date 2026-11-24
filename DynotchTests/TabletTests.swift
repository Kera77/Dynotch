import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// The iPad menu and its link item (spec TB-9).
@MainActor
struct TabletTests {
    @Test func tabletMenuOpensCentredBelowTheButton() {
        let point = MenuAnchor.centred(below: CGRect(x: 100, y: 900, width: 30, height: 22), menuWidth: 200)
        #expect(point == CGPoint(x: 15, y: 896))
    }

    @Test func tabletMenuStaysBelowTheMenuBar() {
        let frame = CGRect(x: 100, y: 960, width: 30, height: 22)
        #expect(MenuAnchor.centred(below: frame, menuWidth: 200, visibleTop: 945).y == 945)
        #expect(MenuAnchor.centred(below: frame, menuWidth: 200, visibleTop: 990).y == 956)
    }

    @Test func theIPadIsChosenInTheKeyboardSection() {
        let titles = ["Mirror or extend to", "iPad", "", "Link keyboard and mouse to", "iPad"]
        let enabled = [false, true, true, false, true]
        #expect(UniversalControlLink.linkItemIndex(titles: titles, enabled: enabled, name: "iPad") == 4)
        // Only in the first section: not the link item.
        #expect(UniversalControlLink.linkItemIndex(titles: ["Mirror or extend to", "iPad"], enabled: [false, true], name: "iPad") == nil)
    }
}
