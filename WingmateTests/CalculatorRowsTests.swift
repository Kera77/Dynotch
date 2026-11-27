import AppKit
import Testing
@testable import Wingmate

/// The result stays on its line when a new line follows it (spec SZ-16).
@MainActor
struct CalculatorRowsTests {
    private func rows(for text: String) -> [CalculatorResultRow] {
        let scroll = CalculatorTextView.makeScrollView(text: text)
        let view = scroll.documentView as? CalculatorTextView
        view?.setFrameSize(NSSize(width: 400, height: 300))
        return view?.resultRows() ?? []
    }

    @Test func aNewLineAfterTheLastKeepsItsResultInPlace() throws {
        let before = try #require(rows(for: "10+1\n1200*12").last)
        let after = try #require(rows(for: "10+1\n1200*12\n").last)
        #expect(after.text == before.text)
        #expect(abs(after.lineRect.minY - before.lineRect.minY) < 0.5)
        #expect(abs(after.baseline - before.baseline) < 0.5)
        #expect(after.baseline > after.lineRect.minY)
    }
}
