import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// v0.34: the capsule-shaped notch (spec N-11), hiding over full-screen apps (spec N-12).
@MainActor
struct V034Tests {
    private let notchWidth: CGFloat = 185

    @Test func theBareNotchReachesARadiusBeyondTheNotch() {
        let capsule = NotchCorners.capsule(width: notchWidth, offset: 0, notchWidth: notchWidth, radius: 16)
        #expect(abs(capsule.width - (notchWidth + 32)) < 0.001)
        #expect(abs(capsule.shift) < 0.001)
    }

    @Test func wideContentKeepsItsSize() {
        let capsule = NotchCorners.capsule(width: notchWidth + 200, offset: 0, notchWidth: notchWidth, radius: 16)
        #expect(abs(capsule.width - (notchWidth + 200)) < 0.001)
        #expect(abs(capsule.shift) < 0.001)
    }

    @Test func contentOnOneSideGetsRoomOnTheOther() {
        // 120 pt of badges left of the notch, nothing right of it: centred 60 pt to the left.
        let capsule = NotchCorners.capsule(width: notchWidth + 120, offset: -60, notchWidth: notchWidth, radius: 16)
        #expect(abs(capsule.width - (notchWidth + 136)) < 0.001)
        // The capsule's centre moves 8 pt right, so its right end is 16 pt beyond the notch.
        #expect(abs(capsule.shift - 8) < 0.001)
        let rightEnd = (capsule.width / 2) + (-60 + capsule.shift)
        #expect(abs(rightEnd - (notchWidth / 2 + 16)) < 0.001)
    }

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
        let name = "V034Tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        #expect(AppSettings(defaults: defaults).hideInFullScreen)
    }
}
