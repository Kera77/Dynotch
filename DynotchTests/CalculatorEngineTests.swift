@testable import Dynotch
import Testing

struct CalculatorEngineTests {
    @Test(arguments: [
        ("1 + 2", "3"),
        ("10 / 4", "2,5"),
        ("(2 + 3) * 4", "20"),
        ("2 + 3 * 4", "14"),
        ("2 ^ 10", "1\u{00A0}024"),
        ("-5 + 2", "-3"),
        ("0,1 + 0,2", "0,3"),
        ("1.5 + 1,5", "3"),
        ("3 x 4", "12"),
        ("7 ÷ 2", "3,5"),
        ("1200 * 1,27", "1\u{00A0}524"),
        ("1 000 + 500", "1\u{00A0}500"),
        ("1 000 000 / 3", "333\u{00A0}333,33333333")
    ])
    func calculates(_ line: String, _ expected: String) {
        #expect(CalculatorEngine.result(for: line) == expected)
    }

    @Test func percent() {
        #expect(CalculatorEngine.result(for: "200 + 10%") == "220")
        #expect(CalculatorEngine.result(for: "100 - 25%") == "75")
        #expect(CalculatorEngine.result(for: "200 * 15%") == "30")
    }

    @Test(arguments: ["", "hello", "42", "2 +", "2 * (3 + ", "5 / 0", "12 34 + 1", "bevásárlás 1200"])
    func showsNothingForNonCalculations(_ line: String) {
        #expect(CalculatorEngine.result(for: line) == nil)
    }

    @Test func evaluateAcceptsSingleNumbers() {
        #expect(CalculatorEngine.evaluate("42") == 42)
        #expect(CalculatorEngine.evaluate("1 200,5") == 1200.5)
    }

    @Test func formatting() {
        #expect(CalculatorEngine.format(0) == "0")
        #expect(CalculatorEngine.format(-1234.5) == "-1\u{00A0}234,5")
        #expect(CalculatorEngine.format(1_000_000) == "1\u{00A0}000\u{00A0}000")
        #expect(CalculatorEngine.format(-0.000000001) == "0")
    }
}
