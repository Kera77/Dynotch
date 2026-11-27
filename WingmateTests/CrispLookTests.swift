import SwiftUI
import Testing
@testable import Wingmate

/// The trial crisp look (spec D-18).
struct CrispLookTests {
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
