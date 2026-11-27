import Foundation
import Testing
@testable import Wingmate

@MainActor
struct WingsContentTests {
    private let geometry = NotchGeometry.make(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
        auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
    )

    @Test func eachWingIsAsWideAsItsContent() {
        let sides = geometry.wingsSides(left: 80, right: 200)
        #expect(sides == WingsSides(left: 80, right: 200))
        #expect(sides.offset == 60)
        #expect(geometry.wingsSize(sides).width == geometry.notchSize.width + 280)
        // An empty side keeps its margins; neither side passes two thirds of the display.
        #expect(geometry.wingsSides(left: 0, right: 0).left == NotchGeometry.wingsMinSide)
        let huge = geometry.wingsSides(left: 10_000, right: 10_000)
        #expect(geometry.wingsSize(huge).width <= 1512 * 2 / 3 + 0.5)
        // Widened for every device, the left side may reach the display's edge (spec PV-31).
        let wide = geometry.wingsSides(left: 10_000, right: 100, wideLeft: true)
        #expect(wide.left == geometry.notchRect.minX)
    }

    @Test func daysBesideToday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 10)))
        #expect(WingFormat.day(of: now.addingTimeInterval(3600), now: now, calendar: calendar) == nil)
        #expect(WingFormat.day(of: now.addingTimeInterval(86_400), now: now, calendar: calendar) == "Tomorrow")
        let friday = now.addingTimeInterval(2 * 86_400)
        #expect(WingFormat.day(of: friday, now: now, calendar: calendar) == friday.formatted(.dateTime.weekday(.wide)))
        let later = now.addingTimeInterval(9 * 86_400)
        #expect(WingFormat.day(of: later, now: now, calendar: calendar) == later.formatted(.dateTime.month(.abbreviated).day()))
    }

    @Test func noteBodyStartsOnTheSecondLine() {
        #expect(NotchView.noteBody("Title\n\nFirst line\n  Second  \n") == "First line · Second")
        #expect(NotchView.noteBody("Only a title").isEmpty)
    }
}
