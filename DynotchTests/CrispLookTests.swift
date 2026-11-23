@testable import Dynotch
import SwiftUI
import Testing

/// The trial crisp look (spec D-18).
struct CrispLookTests {
    @Test func crispTintIsDeeperAndCapped() {
        #expect(DesignBackground<Rectangle>.tint(0.45, crisp: false) == 0.45)
        #expect(abs(DesignBackground<Rectangle>.tint(0.45, crisp: true) - 0.6) < 0.0001)
        #expect(DesignBackground<Rectangle>.tint(0.7, crisp: true) == 0.75)
    }

    @Test func crispBlursFullyUnderTheGlass() {
        #expect(DesignBackground<Rectangle>.blurOpacity(glass: true, isOpen: true, openOpacity: 1, crisp: true) == 1)
        #expect(DesignBackground<Rectangle>.blurOpacity(glass: true, isOpen: false, openOpacity: 1, crisp: true) == 0)
        #expect(DesignBackground<Rectangle>.blurOpacity(glass: true, isOpen: true, openOpacity: 1) == 0.75)
    }
}

struct SystemAccentTests {
    @Test func mapsTheSystemSetting() {
        #expect(SystemAccent.color(forSetting: nil) == .systemBlue)
        #expect(SystemAccent.color(forSetting: 0) == .systemRed)
        #expect(SystemAccent.color(forSetting: 5) == .systemPurple)
        #expect(SystemAccent.color(forSetting: -1) == .systemGray)
    }
}
