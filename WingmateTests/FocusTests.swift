import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

/// Focus following the pointer (spec F-8, F-13).
@MainActor
struct FocusTests {
    @Test func focusFollowsWindowsButNotOntoPopUpsOrAwayFromDialogs() {
        let big = CGRect(x: 0, y: 0, width: 800, height: 600)
        let other = ScreenWindow(id: 5, pid: 11, bounds: big, layer: 0, alpha: 1)
        #expect(FocusRules.shouldSwitch(target: other, frontPID: 10, focusedWindow: 1, focusedIsDialog: false, targetIsStandard: true))
        #expect(FocusRules.shouldSwitch(target: other, frontPID: nil, focusedWindow: nil, focusedIsDialog: false, targetIsStandard: true))
        // The same app's other window, e.g. on the other display.
        let sibling = ScreenWindow(id: 6, pid: 10, bounds: big, layer: 0, alpha: 1)
        #expect(FocusRules.shouldSwitch(target: sibling, frontPID: 10, focusedWindow: 1, focusedIsDialog: false, targetIsStandard: true))
        #expect(!FocusRules.shouldSwitch(target: sibling, frontPID: 10, focusedWindow: 6, focusedIsDialog: false, targetIsStandard: true))
        #expect(!FocusRules.shouldSwitch(target: sibling, frontPID: 10, focusedWindow: 1, focusedIsDialog: true, targetIsStandard: true))
        #expect(!FocusRules.shouldSwitch(target: sibling, frontPID: 10, focusedWindow: nil, focusedIsDialog: false, targetIsStandard: true))
        // A drop-down of the same app, as big as a window (DataGrip's project picker).
        #expect(!FocusRules.shouldSwitch(target: sibling, frontPID: 10, focusedWindow: 1, focusedIsDialog: false, targetIsStandard: false))
        // Another app's window is never asked about.
        #expect(FocusRules.shouldSwitch(target: other, frontPID: 10, focusedWindow: 1, focusedIsDialog: false, targetIsStandard: false))
        let popUp = ScreenWindow(id: 7, pid: 10, bounds: CGRect(x: 0, y: 0, width: 200, height: 40), layer: 0, alpha: 1)
        #expect(!FocusRules.shouldSwitch(target: popUp, frontPID: 10, focusedWindow: 1, focusedIsDialog: false, targetIsStandard: true))
    }

    @Test func wingmateMenuOnScreenIsSeen() {
        let menu = ScreenWindow(id: 1, pid: 42, bounds: .zero, layer: FocusRules.popUpMenuLayer, alpha: 1)
        let panel = ScreenWindow(id: 2, pid: 42, bounds: .zero, layer: 27, alpha: 1)
        #expect(FocusRules.hasOpenMenu(in: [panel, menu], ownPID: 42))
        #expect(!FocusRules.hasOpenMenu(in: [panel], ownPID: 42))
        #expect(!FocusRules.hasOpenMenu(in: [menu], ownPID: 7))
    }
}
