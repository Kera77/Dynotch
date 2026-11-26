import CoreGraphics
@testable import Dynotch
import Foundation
import SwiftUI
import Testing

@MainActor
struct HomeTilesTests {
    private func makeDefaults() -> UserDefaults {
        let name = "DynotchTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeModel() -> NotchViewModel {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        return NotchViewModel(settings: AppSettings(defaults: makeDefaults()), geometry: geometry, screenName: "Test")
    }

    // MARK: - Grid (spec HT-38, HT-39)

    @Test func tilesKeepTheirPlaceAndPushWhatTheyCover() {
        var slots = HomeLayout.slots(from: [.cpu, .memory, .clockWide, .swap])
        // In five columns everything fits the first row, in order.
        #expect(slots.map(\.column) == [0, 1, 2, 4])
        #expect(slots.allSatisfy { $0.row == 0 })
        // Put at the fifth place of the second row, it stays there.
        slots = HomeLayout.put(.disk, row: 1, column: 4, in: slots)
        #expect(slots.first { $0.tile == .disk } == HomeSlot(tile: .disk, row: 1, column: 4))
        // A wide tile dropped on the last column is kept inside the grid; the tile it covers moves on.
        slots = HomeLayout.put(.nowPlayingWide, row: 1, column: 4, in: slots)
        #expect(slots.first { $0.tile == .nowPlayingWide } == HomeSlot(tile: .nowPlayingWide, row: 1, column: 3))
        #expect(slots.first { $0.tile == .disk } == HomeSlot(tile: .disk, row: 2, column: 0))
    }

    @Test func theWidestRowSetsTheWidthAtLeastThree() {
        let two = [HomeSlot(tile: .cpu, row: 2, column: 1), HomeSlot(tile: .memory, row: 2, column: 2)]
        let narrow = HomeLayout.shown(two)
        #expect(narrow.columns == 3)
        // Empty rows above and columns left are left out; two columns are centred in three.
        #expect(narrow.placements.map(\.row) == [0, 0])
        #expect(narrow.placements.map(\.column) == [0, 1])
        let wide = HomeLayout.shown(two + [HomeSlot(tile: .clockWide, row: 3, column: 3)])
        #expect(wide.columns == 4)
        let normal: CGFloat = 560
        #expect(abs(HomeLayout.panelWidth(columns: 5, normalWidth: normal) - normal) < 0.01)
        #expect(HomeLayout.panelWidth(columns: 3, normalWidth: normal) < normal)
    }

    @Test func theOldOrderIsLaidOutOnce() {
        let defaults = makeDefaults()
        defaults.set(["stats.cpu", "home.clockWide"], forKey: "home.tiles")
        let settings = HomeTileSettings(defaults: defaults)
        #expect(settings.slots.map(\.column) == [0, 1])
        #expect(HomeSlot(saved: "stats.cpu@2,9") == HomeSlot(tile: .cpu, row: 2, column: 4))
        #expect(HomeSlot(saved: "gone.tile@0,0") == nil)
    }

    // MARK: - Catalog and saving (spec HT-14, HT-15, HT-23)

    @Test func idsAreUniqueAndUnknownOnesAreDropped() {
        #expect(Set(HomeTile.allCases.map(\.rawValue)).count == HomeTile.allCases.count)
        #expect(HomeTile.decode(["stats.cpu", "gone.tile", "stats.cpu", "home.clock"]) == [.cpu, .clock])
        #expect(HomeTile.allCases.allSatisfy { $0.rawValue.hasPrefix($0.feature.rawValue + ".") })
    }

    @Test func catalogFollowsTheModuleOrder() {
        let groups = HomeTileGroup.catalog(order: [.stats, .calendar, .home])
        #expect(Array(groups.map(\.feature).prefix(3)) == [.stats, .calendar, .home])
        #expect(groups.count == FeatureID.allCases.count)
        #expect(groups.first?.tiles.count == 7)
    }

    @Test func tilesArePlacedMovedRemovedAndSaved() {
        let defaults = makeDefaults()
        let settings = HomeTileSettings(defaults: defaults)
        #expect(settings.tiles == HomeTile.defaults)
        settings.add(.disk)
        #expect(settings.contains(.disk))
        settings.put(.disk, row: 4, column: 2)
        #expect(settings.slots.contains(HomeSlot(tile: .disk, row: 4, column: 2)))
        settings.remove(.cpu)
        settings.backGesture = .swipeDown
        let reloaded = HomeTileSettings(defaults: defaults)
        #expect(Set(reloaded.slots) == Set(settings.slots))
        #expect(!reloaded.contains(.cpu))
        #expect(reloaded.backGesture == .swipeDown)
        reloaded.reset()
        #expect(reloaded.tiles == HomeTile.defaults)
    }

    // MARK: - Opening and going back (spec HT-11…HT-13)

    @Test func aTileOpensItsModuleAndGoesBackHome() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.home)
        model.openTile(.cpu, anchor: .topLeading)
        #expect(model.currentFeature == .stats)
        #expect(model.tileOpening?.tile == .cpu)
        model.backToHome()
        #expect(model.currentFeature == .home)
        #expect(model.tileOpening == nil)
    }

    @Test func switchingModulesOrClosingLeavesTheTile() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.home)
        model.openTile(.nextEvent, anchor: .center)
        model.select(.notes)
        #expect(model.tileOpening == nil)
        model.select(.home)
        model.openTile(.nextEvent, anchor: .center)
        model.setExpanded(false)
        #expect(model.tileOpening == nil)
    }

    @Test func homeTilesDoNotOpenAnything() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.home)
        model.openTile(.clock, anchor: .center)
        #expect(model.tileOpening == nil)
        #expect(model.currentFeature == .home)
    }

    // MARK: - Back gestures (spec HT-12)

    @Test func aPinchInFiresOncePerGesture() {
        var gesture = TileBackGesture()
        var fired = gesture.pinch(phase: .began, magnification: -0.1)
        #expect(fired == nil)
        fired = gesture.pinch(phase: .changed, magnification: -0.1)
        #expect(fired == .inward)
        fired = gesture.pinch(phase: .changed, magnification: -0.3)
        #expect(fired == nil)
        // Pinching out is the other direction (spec N-28).
        fired = gesture.pinch(phase: .began, magnification: 0.5)
        #expect(fired == .outward)
    }

    @Test func oneGestureFiresOnlyOneWay() {
        var gesture = TileBackGesture()
        #expect(gesture.pinch(phase: .began, magnification: 0.2) == .outward)
        // Pinching back in within the same gesture does not close what it just opened.
        #expect(gesture.pinch(phase: .changed, magnification: -0.6) == nil)
    }

    @Test func aSwipeDownFiresOnlyWhenMostlyDown() {
        var gesture = TileBackGesture()
        var fired = gesture.swipe(phase: .began, fingerDown: 20, fingerSideways: 60)
        #expect(!fired)
        fired = gesture.swipe(phase: .changed, fingerDown: 30, fingerSideways: 0)
        #expect(!fired)
        fired = gesture.swipe(phase: .began, fingerDown: 25, fingerSideways: 2)
        #expect(!fired)
        fired = gesture.swipe(phase: .changed, fingerDown: 25, fingerSideways: 2)
        #expect(fired)
        // The rest of that swipe, momentum included, is swallowed; a new swipe is not.
        var swallowed = gesture.swallowsRest(began: false, inGesture: true)
        #expect(swallowed)
        swallowed = gesture.swallowsRest(began: false, inGesture: false)
        #expect(!swallowed)
        swallowed = gesture.swallowsRest(began: true, inGesture: true)
        #expect(!swallowed)
    }

    // MARK: - Second part (spec HT-14, HT-16, HT-18, HT-27)

    @Test func everyModuleHasATile() {
        let withTiles = Set(HomeTile.allCases.map(\.feature))
        #expect(FeatureID.allCases.allSatisfy { withTiles.contains($0) })
    }

    /// A tile dragged in the notch lands in the saved grid, shifted back and kept inside (spec HT-44).
    @Test func dropInTheNotchMapsBackToTheGrid() {
        let slots = [HomeSlot(tile: .clock, row: 2, column: 3)]
        // Shown: the empty rows above are left out, the one tile centred in three columns.
        let shown = HomeLayout.shown(slots)
        #expect(shown.placements.first?.row == 0)
        let back = HomeLayout.dropCell(of: .clock, shownRow: 0, shownColumn: shown.placements[0].column, in: slots)
        #expect(back == GridCell(row: 2, column: 3))
        let wide = HomeLayout.dropCell(of: .days, shownRow: 0, shownColumn: 4, in: slots)
        #expect(wide.column == 0)
    }

    @Test func everySizeIsUsedAndFitsTheGrid() {
        let sizes = Set(HomeTile.allCases.map(\.size))
        #expect(sizes == [.small, .wide, .tall, .large, .wideLarge, .tallLarge, .strip])
        let placements = HomeLayout.placements(HomeLayout.slots(from: HomeTile.allCases))
        #expect(placements.count == HomeTile.allCases.count)
        #expect(placements.allSatisfy { $0.column + $0.size.columns <= HomeLayout.columns })
    }

    @Test func aPartOfTheTodayTileOpensItsModule() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.home)
        model.openTile(.today, part: .reminders, anchor: .center)
        #expect(model.currentFeature == .reminders)
        #expect(model.tileOpening?.feature == .reminders)
        model.backToHome()
        #expect(model.currentFeature == .home)
    }

    @Test func theMonthPagesOnlyUnderThePointer() {
        let pager = MonthTilePager()
        #expect(!pager.step(by: 1))
        pager.isHovered = true
        #expect(pager.step(by: 1))
        #expect(pager.step(by: 1))
        #expect(pager.offset == 2)
        let now = Date()
        let start = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
        let expected = Calendar.current.date(byAdding: .month, value: 2, to: start)
        #expect(pager.month(now: now) == expected)
        pager.reset()
        #expect(pager.offset == 0)
    }

    @Test func monthCellsStartOnTheRightWeekday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        // 1 November 2026 is a Sunday: six empty cells before it when weeks start on Monday.
        let november = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)))
        let cells = HomeMonthGrid.cells(of: november, calendar: calendar)
        #expect(cells.prefix(6).allSatisfy { $0 == nil })
        #expect(cells.count == 6 + 30)
    }

    @Test func rainAndWeeklyLimitAreFound() {
        let now = Date()
        let hours = [
            WeatherForecast.Hour(time: now.addingTimeInterval(3600), temperature: 10, code: 3, rainChance: 20, isDay: true),
            WeatherForecast.Hour(time: now.addingTimeInterval(7200), temperature: 9, code: 61, rainChance: 70, isDay: true)
        ]
        #expect(WeatherTileContent.nextRain(in: hours, now: now)?.rainChance == 70)
        #expect(WeatherTileContent.nextRain(in: Array(hours.prefix(1)), now: now) == nil)
        let limits = [
            UsageLimit(id: "five_hour", title: "5-hour", utilization: 40, resetsAt: nil),
            UsageLimit(id: "seven_day_opus", title: "Opus", utilization: 10, resetsAt: nil),
            UsageLimit(id: "seven_day", title: "Weekly", utilization: 25, resetsAt: nil)
        ]
        #expect(AITileContent.weekly(in: limits)?.utilization == 25)
    }
}
