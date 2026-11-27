import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

/// Hiding over full-screen apps (spec N-12).
@MainActor
struct FullScreenTests {
    @Test func onlyTheTopEdgeOpensOverAFullScreenApp() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let geometry = NotchGeometry.make(
            screenFrame: screen, safeAreaTop: 32, auxiliaryLeftWidth: 663, auxiliaryRightWidth: 664, menuBarHeight: 32
        )
        #expect(geometry.topEdgeZone.contains(CGPoint(x: screen.midX, y: screen.maxY - 0.5)))
        #expect(!geometry.topEdgeZone.contains(CGPoint(x: screen.midX, y: screen.maxY - 10)))
        #expect(!geometry.topEdgeZone.contains(CGPoint(x: geometry.notchRect.minX - 5, y: screen.maxY - 0.5)))
    }

    @Test func aFullScreenWindowCoversTheWholeScreen() {
        let secondary = CGRect(x: 1512, y: -200, width: 1920, height: 1080)
        let target = FullScreenDetector.windowRect(of: secondary, primaryHeight: 982)
        #expect(target == CGRect(x: 1512, y: 102, width: 1920, height: 1080))
        #expect(FullScreenDetector.covers(target, target))
        // A zoomed window leaves the menu bar free.
        let zoomed = CGRect(x: 1512, y: 127, width: 1920, height: 1055)
        #expect(!FullScreenDetector.covers(zoomed, target))
    }

    @Test func hidingOverFullScreenAppsIsOnByDefault() {
        let name = "FullScreenTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        #expect(AppSettings(defaults: defaults).hideInFullScreen)
    }
}
