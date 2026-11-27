import Foundation
import Testing
@testable import Wingmate

/// The Apple style's mappings (spec D-15, D-16: the only look).
struct AppleStyleTests {
    @Test func followsTheLadders() {
        #expect(AppleStyle.textSize(8) == 9)
        #expect(AppleStyle.textSize(14) == 13)
        #expect(AppleStyle.textSize(22) == 22)
        #expect(AppleStyle.weight(.bold, size: 10) == .semibold)
        #expect(AppleStyle.weight(.bold, size: 22) == .bold)
        #expect(AppleStyle.corner(7) == 8)
        #expect(AppleStyle.corner(10) == 12)
        #expect(AppleStyle.corner(18) == 18)
        #expect(AppleStyle.corner(3) == 3)
        #expect(AppleStyle.level(0.0001) == 0.0001)
        if !AppleStyle.increasesContrast {
            #expect(AppleStyle.level(0.45, crisp: false) == 0.4)
            #expect(AppleStyle.level(0.7, crisp: false) == 0.6)
            #expect(AppleStyle.level(0.9, crisp: false) == 0.86)
            #expect(AppleStyle.level(0.08, crisp: false) == 0.1)
            // The crisp look (spec D-18): stronger text, lighter fills.
            #expect(AppleStyle.level(0.9, crisp: true) == 1)
            #expect(AppleStyle.level(0.7, crisp: true) == 0.68)
            #expect(AppleStyle.level(0.08, crisp: true) == 0.06)
            #expect(AppleStyle.level(0.16, crisp: true) == 0.12)
        }
    }
}
