import Foundation

/// A tile's size in rows and columns (spec HT-2): 1×2 is one row tall and two columns wide.
struct TileSize: Hashable, Sendable {
    let rows: Int
    let columns: Int

    static let small = TileSize(rows: 1, columns: 1)
    static let wide = TileSize(rows: 1, columns: 2)

    var label: String { "\(rows)×\(columns)" }
}

/// A tile the Home can show (spec HT-14). The raw value is the saved id, `module.tile` (spec HT-15).
enum HomeTile: String, CaseIterable, Identifiable, Sendable {
    case clock = "home.clock"
    case clockWide = "home.clockWide"
    case nextEvent = "calendar.nextEvent"
    case cpu = "stats.cpu"
    case memory = "stats.memory"
    case swap = "stats.swap"
    case network = "stats.network"
    case disk = "stats.disk"
    case macBattery = "stats.battery"

    var id: String { rawValue }

    private struct Info: Sendable {
        let feature: FeatureID
        let title: String
        let size: TileSize
    }

    private static let info: [HomeTile: Info] = [
        .clock: Info(feature: .home, title: "Clock", size: .small),
        .clockWide: Info(feature: .home, title: "Clock", size: .wide),
        .nextEvent: Info(feature: .calendar, title: "Next event", size: .small),
        .cpu: Info(feature: .stats, title: "CPU", size: .small),
        .memory: Info(feature: .stats, title: "Memory", size: .small),
        .swap: Info(feature: .stats, title: "Swap", size: .small),
        .network: Info(feature: .stats, title: "Network", size: .small),
        .disk: Info(feature: .stats, title: "Disk", size: .small),
        .macBattery: Info(feature: .stats, title: "Battery", size: .small)
    ]

    /// The module the tile opens (spec HT-11).
    var feature: FeatureID { Self.info[self]?.feature ?? .home }
    var title: String { Self.info[self]?.title ?? rawValue }
    var size: TileSize { Self.info[self]?.size ?? .small }

    /// The first launch's tiles and Reset to default (spec HT-17), of the tiles made so far.
    static let defaults: [HomeTile] = [.clockWide, .nextEvent, .cpu, .memory]

    /// Saved ids back to tiles: unknown ones and repeats are left out (spec HT-15, HT-23).
    static func decode(_ ids: [String]) -> [HomeTile] {
        var tiles: [HomeTile] = []
        for tile in ids.compactMap(HomeTile.init(rawValue:)) where !tiles.contains(tile) {
            tiles.append(tile)
        }
        return tiles
    }
}

/// One module's tiles in the settings' catalog (spec HT-21).
struct HomeTileGroup: Identifiable, Sendable {
    let feature: FeatureID
    let tiles: [HomeTile]

    var id: FeatureID { feature }

    /// The modules in the given order, each with its tiles; modules without a tile are left out.
    static func catalog(order: [FeatureID]) -> [HomeTileGroup] {
        let features = order + FeatureID.allCases.filter { !order.contains($0) }
        return features.compactMap { feature in
            let tiles = HomeTile.allCases.filter { $0.feature == feature }
            return tiles.isEmpty ? nil : HomeTileGroup(feature: feature, tiles: tiles)
        }
    }
}
