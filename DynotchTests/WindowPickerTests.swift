import CoreGraphics
@testable import Dynotch
import Testing

struct WindowPickerTests {
    private let own: pid_t = 100

    private func window(_ id: CGWindowID, pid: pid_t, _ rect: CGRect, layer: Int = 0, alpha: Double = 1) -> ScreenWindow {
        ScreenWindow(id: id, pid: pid, bounds: rect, layer: layer, alpha: alpha)
    }

    /// Spec F-2: the topmost normal window under the pointer, even if it is partly covered elsewhere.
    @Test func picksTopmostNormalWindowUnderPointer() {
        let notes = window(1, pid: 200, CGRect(x: 100, y: 100, width: 300, height: 300))
        let browser = window(2, pid: 300, CGRect(x: 0, y: 0, width: 1000, height: 800))
        let windows = [notes, browser]
        #expect(WindowPicker.window(at: CGPoint(x: 600, y: 500), in: windows, ownPID: own) == browser)
        #expect(WindowPicker.window(at: CGPoint(x: 150, y: 150), in: windows, ownPID: own) == notes)
        #expect(WindowPicker.window(at: CGPoint(x: 1500, y: 500), in: windows, ownPID: own) == nil)
    }

    @Test func menusDockAndFloatingWindowsBlock() {
        let menu = window(9, pid: 400, CGRect(x: 0, y: 0, width: 200, height: 200), layer: 101)
        let browser = window(2, pid: 300, CGRect(x: 0, y: 0, width: 1000, height: 800))
        #expect(WindowPicker.window(at: CGPoint(x: 50, y: 50), in: [menu, browser], ownPID: own) == nil)
        #expect(WindowPicker.window(at: CGPoint(x: 500, y: 50), in: [menu, browser], ownPID: own) == browser)
    }

    @Test func ownAndInvisibleWindowsAreLookedThrough() {
        let notchPanel = window(5, pid: own, CGRect(x: 0, y: 0, width: 1000, height: 300))
        let invisible = window(6, pid: 500, CGRect(x: 0, y: 0, width: 1000, height: 300), alpha: 0)
        let browser = window(2, pid: 300, CGRect(x: 0, y: 0, width: 1000, height: 800))
        #expect(WindowPicker.window(at: CGPoint(x: 50, y: 50), in: [notchPanel, invisible, browser], ownPID: own) == browser)
    }

    @Test func parsesWindowListDictionaries() {
        let info: [[String: Any]] = [
            [
                kCGWindowNumber as String: CGWindowID(42),
                kCGWindowOwnerPID as String: pid_t(300),
                kCGWindowBounds as String: CGRect(x: 10, y: 20, width: 30, height: 40).dictionaryRepresentation,
                kCGWindowLayer as String: 0,
                kCGWindowAlpha as String: 1.0
            ],
            [kCGWindowNumber as String: CGWindowID(1)]
        ]
        let windows = WindowPicker.screenWindows(from: info)
        #expect(windows == [ScreenWindow(id: 42, pid: 300, bounds: CGRect(x: 10, y: 20, width: 30, height: 40), layer: 0, alpha: 1)])
    }
}
