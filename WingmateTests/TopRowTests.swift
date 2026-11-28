import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

/// The controls in the top row, right of the notch (spec TB-1).
struct TopRowTests {
    @Test func topRowOrderKeepsStoredAndAddsNewControls() {
        #expect(TopRowLayout.normalized([]) == TopRowControl.allCases)
        let expected: [TopRowControl] = [.tablet, .spencer, .cleaner, .followMouse, .keyboardLock, .settings, .pin, .toggles, .focus]
        #expect(TopRowLayout.normalized(["settings", "pin", "bogus", "pin"]) == expected)
    }

    @MainActor @Test func topRowMovesAndHidesButNeverSettings() throws {
        let defaults = try #require(UserDefaults(suiteName: "TopRowTests-\(UUID().uuidString)"))
        let layout = TopRowLayout(defaults: defaults)
        layout.move(.settings, to: .tablet)
        #expect(layout.order.first == .settings)
        layout.setShown(.settings, false)
        layout.setShown(.tablet, false)
        #expect(layout.visible.contains(.settings))
        #expect(!layout.visible.contains(.tablet))
        // Kept for the next launch.
        #expect(TopRowLayout(defaults: defaults).order.first == .settings)
    }

    @MainActor @Test func theCleanerButtonIsOffUntilSwitchedOn() throws {
        let defaults = try #require(UserDefaults(suiteName: "TopRowTests-\(UUID().uuidString)"))
        #expect(!TopRowLayout(defaults: defaults).isShown(.cleaner))
        TopRowLayout(defaults: defaults).setShown(.cleaner, true)
        #expect(TopRowLayout(defaults: defaults).isShown(.cleaner))
        TopRowLayout(defaults: defaults).setShown(.cleaner, false)
        #expect(!TopRowLayout(defaults: defaults).isShown(.cleaner))
    }

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
}
