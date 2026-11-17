import CoreGraphics
@testable import Dynotch
import Testing

/// v0.37: calculations among words (spec SZ-11), rounding only where something is shown
/// (spec N-13).
struct V037Tests {
    @Test(arguments: [
        ("Asd: 10*10", "100"),
        ("Rent 1200*12 eur", "14\u{00A0}400"),
        ("Lunch: 2 x 4,5", "9"),
        ("total: (2+3)*2", "10")
    ])
    func wordsAroundACalculation(_ line: String, _ expected: String) {
        #expect(CalculatorEngine.result(for: line) == expected)
    }

    @Test(arguments: ["Asd: 42", "Price 1200", "two apples and 3 pears + 2", "note: nothing here"])
    func wordsWithoutACalculation(_ line: String) {
        #expect(CalculatorEngine.result(for: line) == nil)
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
