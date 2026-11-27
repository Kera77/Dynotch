import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

/// The rounded, capsule-shaped notch (spec N-11, N-13).
@MainActor
struct NotchShapeTests {
    private let notchWidth: CGFloat = 185

    @Test func roundedNotchIsOnByDefaultAndRemembered() {
        let name = "NotchShapeTests-rounded-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: defaults)
        #expect(settings.roundedNotch)
        settings.roundedNotch = false
        #expect(!AppSettings(defaults: defaults).roundedNotch)
    }

    @Test func oneRowGetsRoundEnds() {
        #expect(abs(NotchCorners.radius(notchHeight: 32) - 16) < 0.001)
        #expect(abs(NotchCorners.radius(notchHeight: 37) - 19) < 0.001)
    }

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

    @Test func onlyTheSideWithContentIsRound() {
        let notch: CGFloat = 185
        // Badges on the left only: the left side is round and reaches out, the right one is not.
        let left = NotchCorners.capsule(width: notch + 120, offset: -60, notchWidth: notch, radius: 16, onlyWhereShown: true)
        #expect(left.roundsLeading)
        #expect(!left.roundsTrailing)
        #expect(abs(left.width - (notch + 120)) < 0.001)
        #expect(abs(left.shift) < 0.001)
        // Nothing beside the notch: no side is round.
        let bare = NotchCorners.capsule(width: notch, offset: 0, notchWidth: notch, radius: 16, onlyWhereShown: true)
        #expect(!bare.roundsLeading && !bare.roundsTrailing)
        #expect(abs(bare.width - notch) < 0.001)
        // Without the option both sides are round.
        let both = NotchCorners.capsule(width: notch, offset: 0, notchWidth: notch, radius: 16)
        #expect(both.roundsLeading && both.roundsTrailing)
    }
}
