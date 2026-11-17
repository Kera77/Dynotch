import CoreGraphics
@testable import Dynotch
import Testing

/// v0.38: the software-drawn pointer does not stop focus from following it (spec F-12).
struct V038Tests {
    @Test func thePointerWindowIsLookedThrough() {
        let own: pid_t = 1
        let pointer = ScreenWindow(
            id: 1, pid: 99, bounds: CGRect(x: 776, y: 182, width: 23, height: 22), layer: WindowPicker.cursorLayer, alpha: 1
        )
        let menu = ScreenWindow(id: 2, pid: 50, bounds: CGRect(x: 700, y: 150, width: 200, height: 300), layer: 101, alpha: 1)
        let browser = ScreenWindow(id: 3, pid: 7, bounds: CGRect(x: 0, y: 39, width: 1920, height: 1203), layer: 0, alpha: 1)
        let point = CGPoint(x: 788, y: 193)
        #expect(WindowPicker.window(at: point, in: [pointer, browser], ownPID: own) == browser)
        // A menu on top still means "do nothing".
        #expect(WindowPicker.window(at: point, in: [pointer, menu, browser], ownPID: own) == nil)
    }
}
