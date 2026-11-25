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
        #expect(groups.first?.tiles.count == 6)
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
}
