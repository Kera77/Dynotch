import AppKit
import CoreGraphics
import Testing
@testable import Wingmate

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

    /// Spec SZ-9: the copied number has no thousands separators.
    @Test func clipboardText() {
        #expect(CalculatorResultsView.clipboardText(for: CalculatorEngine.format(1524.5)) == "1524,5")
        #expect(CalculatorResultsView.clipboardText(for: "100") == "100")
    }

    /// Regression: results were drawn outside the text view's drawing area and never showed.
    @Test @MainActor func editorExposesResultRowsInsideTheResultColumn() throws {
        let scrollView = CalculatorTextView.makeScrollView(text: "10*10\nhello\n200 + 10%")
        scrollView.frame = CGRect(x: 0, y: 0, width: 500, height: 160)
        scrollView.layoutSubtreeIfNeeded()
        let textView = try #require(scrollView.documentView as? CalculatorTextView)

        let rows = textView.resultRows()
        #expect(rows.map(\.text) == ["100", "220"])
        #expect(textView.resultsView.superview === textView)
        #expect(textView.resultsView.frame.width == CalculatorTextView.resultColumnWidth)
        #expect(textView.resultsView.frame.maxX == textView.bounds.maxX)
        #expect(rows[0].lineRect.minY < rows[1].lineRect.minY)

        let board = NSPasteboard(name: NSPasteboard.Name("wingmate-tests"))
        textView.resultsView.pasteboard = board
        #expect(textView.resultsView.copyResult(at: CGPoint(x: 40, y: rows[1].lineRect.midY)))
        #expect(board.string(forType: .string) == "220")
        #expect(!textView.resultsView.copyResult(at: CGPoint(x: 40, y: rows[0].lineRect.maxY + 8)))
    }

    @Test func resultsAndSummaryOfWholeText() {
        let text = "10*10\nrezsi\n\n  1200 * 1,27  \n42"
        #expect(CalculatorEngine.results(in: text).map(\.line) == ["10*10", "1200 * 1,27"])
        #expect(CalculatorEngine.summary(of: text) == "10*10 = 100\n1200 * 1,27 = 1 524")
        #expect(CalculatorEngine.summary(of: "csak szöveg").isEmpty)
    }

    @Test func popoverArrowStaysInsideRoundedCorners() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 300)
        for arrowX in [-50.0, 5, 200, 399, 900] {
            let bounds = PopoverShape(arrowX: arrowX).path(in: rect).boundingRect
            #expect(abs(bounds.minX - rect.minX) < 0.5)
            #expect(abs(bounds.maxX - rect.maxX) < 0.5)
            #expect(abs(bounds.minY - rect.minY) < 0.5)
            #expect(abs(bounds.maxY - rect.maxY) < 0.5)
        }
    }

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
}
