@testable import Dynotch
import Foundation
import Testing

/// Small notices beside the notch in Wings mode (spec PV-37, PV-38).
@MainActor
struct WingsPeekTests {
    @Test func noticeSaysWhoItIsFrom() {
        let now = Date()
        #expect(StickyNotice(title: "Claude finished", detail: "app", date: now).source == "Claude")
        #expect(StickyNotice(title: "Wingmate updated", detail: "", date: now, symbol: "arrow.down.circle.fill").source == "Wingmate")
        #expect(StickyNotice(title: "ChatGPT finished", detail: "", date: now, iconApp: "com.openai.codex").source == "ChatGPT")
        #expect(StickyNotice.answered(by: "Claude", in: "Chat").source == "Claude")
        #expect(StickyNotice.answered(by: "Claude", in: "Chat").opensChat)
    }

    @Test func peekLineIsTheWholeFirstLine() {
        let long = String(repeating: "word ", count: 30)
        #expect(NotchView.peekLine("\n  \(long)\nsecond") == long.trimmingCharacters(in: .whitespaces))
        #expect(NotchView.peekLine("") == "")
    }

    @Test func peekSidesKeepTheNotchInPlace() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        // A short left side and a long right one: the shape moves right by half the difference.
        let sides = geometry.wingsSides(left: 90, right: 300)
        let rect = geometry.rect(for: geometry.wingsSize(sides)).offsetBy(dx: sides.offset, dy: 0)
        #expect(abs(rect.minX + sides.left - geometry.notchRect.minX) < 0.5)
        #expect(abs(rect.maxX - sides.right - geometry.notchRect.maxX) < 0.5)
    }
}
