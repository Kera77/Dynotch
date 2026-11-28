import AppKit
import Testing
@testable import Wingmate

/// The Focus list's instant highlight and dropping-down lengths (spec FC-10).
@MainActor
struct FocusListMotionTests {
    @Test func lengthsStartClosedWithTheirRowsFromTheTop() {
        let rows = (0..<3).map { FocusRowView(title: "Length \($0)", kind: .length, width: 240) {} }
        let view = FocusLengthsView(rows: rows, width: 240)
        #expect(view.frame.height == 0)
        #expect(view.fullHeight == 3 * FocusRowView.height)
        #expect(rows.map(\.frame.origin.y) == [0, FocusRowView.height, 2 * FocusRowView.height])
    }

    @Test func foldingIsUnfoldingBackwards() {
        let full: CGFloat = 72
        for progress in stride(from: 0.0, through: 1.0, by: 0.25) {
            let down = FocusLengthsView.height(from: 0, to: full, progress: progress)
            let back = FocusLengthsView.height(from: full, to: 0, progress: 1 - progress)
            #expect(abs(down - back) < 0.001)
        }
        #expect(FocusLengthsView.height(from: 0, to: full, progress: 2) == full)
    }

    @Test func onlyOneRowIsHighlighted() {
        let first = FocusRowView(title: "Work", kind: .command, width: 240) {}
        let second = FocusRowView(title: "Sleep", kind: .command, width: 240) {}
        FocusRowView.hover(first)
        #expect(first.isHovered && !second.isHovered)
        FocusRowView.hover(second)
        #expect(!first.isHovered && second.isHovered)
        FocusRowView.hover(nil)
        #expect(!second.isHovered)
    }
}
