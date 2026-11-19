@testable import Dynotch
import Foundation
import Testing

/// The Apple style's mappings (spec D-15); off, every value stays as it was.
@Suite(.serialized) struct AppleStyleTests {
    private func with(_ isOn: Bool, _ body: () -> Void) {
        let old = UserDefaults.standard.object(forKey: AppleStyle.key)
        UserDefaults.standard.set(isOn, forKey: AppleStyle.key)
        body()
        UserDefaults.standard.set(old, forKey: AppleStyle.key)
    }

    @Test func offKeepsEverything() {
        with(false) {
            #expect(AppleStyle.textSize(8) == 8)
            #expect(AppleStyle.level(0.45) == 0.45)
            #expect(AppleStyle.corner(7) == 7)
            #expect(AppleStyle.weight(.bold, size: 9) == .bold)
        }
    }

    @Test func onFollowsTheLadders() {
        with(true) {
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
                #expect(AppleStyle.level(0.45) == 0.4)
                #expect(AppleStyle.level(0.7) == 0.6)
                #expect(AppleStyle.level(0.9) == 0.86)
                #expect(AppleStyle.level(0.08) == 0.1)
            }
        }
    }
}
