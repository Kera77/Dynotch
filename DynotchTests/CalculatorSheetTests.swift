@testable import Dynotch
import Testing

/// Variables, "% of", units and totals (spec SZ-12…SZ-15).
struct CalculatorSheetTests {
    @Test func variablesAndTotals() {
        let results = CalculatorSheet.results(for: ["price = 1200", "price * 2", "total", "", "5 + 5"])
        #expect(results == ["1\u{00A0}200", "2\u{00A0}400", "3\u{00A0}600", nil, "10"])
    }

    @Test func percentOf() {
        #expect(CalculatorSheet.results(for: ["20% of 340"]) == ["68"])
    }

    @Test func units() {
        #expect(UnitConversion.convert("5 km in m") == "5\u{00A0}000 m")
        #expect(UnitConversion.convert("100 c to f") == "212 f")
        #expect(UnitConversion.convert("5 km in kg") == nil)
        #expect(UnitConversion.convert("hello") == nil)
    }

    @Test func plainLinesStayAsBefore() {
        #expect(CalculatorSheet.results(for: ["hello", "Asd: 10*10", "42"]) == [nil, "100", nil])
    }
}
