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

    // MARK: - Grid (spec HT-3, HT-4)

    @Test func columnsGrowWithTheWidthAndAreAtLeastTwo() {
        #expect(HomeLayout.columns(for: 120) == 2)
        #expect(HomeLayout.columns(for: 300) == 2)
        #expect(HomeLayout.columns(for: 324) == 3)
        #expect(HomeLayout.columns(for: 640) == 6)
    }

    @Test func aSmallTileFillsTheHoleAWideOneLeft() {
        // cpu | memory | (wide does not fit) ; next row: wide clock; cpu… memory… swap fills row 0's end.
        let tiles: [HomeTile] = [.cpu, .memory, .clockWide, .swap]
        let placements = HomeLayout.place(tiles, columns: 3)
        #expect(placements.map(\.row) == [0, 0, 1, 0])
        #expect(placements.map(\.column) == [0, 1, 0, 2])
        #expect(HomeLayout.rows(of: placements) == 2)
    }

    @Test func aTileWiderThanTheGridIsNarrowed() {
        let placements = HomeLayout.place([.clockWide], columns: 1)
        #expect(placements.first?.size == TileSize(rows: 1, columns: 1))
    }

    // MARK: - Catalog and saving (spec HT-14, HT-15, HT-23)

    @Test func idsAreUniqueAndUnknownOnesAreDropped() {
        #expect(Set(HomeTile.allCases.map(\.rawValue)).count == HomeTile.allCases.count)
        #expect(HomeTile.decode(["stats.cpu", "gone.tile", "stats.cpu", "home.clock"]) == [.cpu, .clock])
        #expect(HomeTile.allCases.allSatisfy { $0.rawValue.hasPrefix($0.feature.rawValue + ".") })
    }

    @Test func catalogFollowsTheModuleOrder() {
        let groups = HomeTileGroup.catalog(order: [.stats, .calendar, .home])
        #expect(groups.map(\.feature) == [.stats, .calendar, .home])
        #expect(groups.first?.tiles.count == 7)
    }

    @Test func tilesArePlacedMovedRemovedAndSaved() {
        let defaults = makeDefaults()
        let settings = HomeTileSettings(defaults: defaults)
        #expect(settings.tiles == HomeTile.defaults)
        settings.place(.disk)
        #expect(settings.tiles.last == .disk)
        // Dropped on the first tile: before it.
        settings.place(.disk, at: 0)
        #expect(settings.tiles.first == .disk)
        // Moved forward onto the third tile: just before it.
        let third = settings.tiles[2]
        settings.place(.disk, at: 2)
        #expect(settings.tiles.firstIndex(of: .disk) == settings.tiles.firstIndex(of: third).map { $0 - 1 })
        settings.remove(.cpu)
        settings.backGesture = .swipeDown
        let reloaded = HomeTileSettings(defaults: defaults)
        #expect(reloaded.tiles == settings.tiles)
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
        #expect(!fired)
        fired = gesture.pinch(phase: .changed, magnification: -0.1)
        #expect(fired)
        fired = gesture.pinch(phase: .changed, magnification: -0.3)
        #expect(!fired)
        // Pinching out never goes back.
        fired = gesture.pinch(phase: .began, magnification: 0.5)
        #expect(!fired)
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
    }

    // MARK: - Second part (spec HT-14, HT-16, HT-18, HT-27)

    @Test func everyModuleHasATile() {
        let withTiles = Set(HomeTile.allCases.map(\.feature))
        #expect(FeatureID.allCases.allSatisfy { withTiles.contains($0) })
    }

    @Test func everySizeIsUsedAndFitsAGridOfTwo() {
        let sizes = Set(HomeTile.allCases.map(\.size))
        #expect(sizes == [.small, .wide, .tall, .large, .wideLarge, .tallLarge])
        let placements = HomeLayout.place(HomeTile.allCases, columns: 2)
        #expect(placements.count == HomeTile.allCases.count)
        #expect(placements.allSatisfy { $0.column + $0.size.columns <= 2 })
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
