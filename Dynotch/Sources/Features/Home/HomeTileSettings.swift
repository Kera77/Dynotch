import Foundation
import Observation

/// The tiles on the Home and their own settings (spec HT-23, HT-29).
@MainActor
@Observable
final class HomeTileSettings {
    static let shared = HomeTileSettings()

    private enum Key {
        static let tiles = "home.tiles"
        static let worldClockZone = "home.worldClockZone"
        static let runCommand = "home.runCommand"
        static let runName = "home.runName"
    }

    private(set) var tiles: [HomeTile] { didSet { defaults.set(tiles.map(\.rawValue), forKey: Key.tiles) } }

    /// The World clock tile's time zone, an IANA name (spec HT-29).
    var worldClockZone: String { didSet { defaults.set(worldClockZone, forKey: Key.worldClockZone) } }
    /// The Run tile's command and the name it shows (spec HT-29).
    var runCommand: String { didSet { defaults.set(runCommand, forKey: Key.runCommand) } }
    var runName: String { didSet { defaults.set(runName, forKey: Key.runName) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tiles = defaults.stringArray(forKey: Key.tiles).map(HomeTile.decode) ?? HomeTile.defaults
        worldClockZone = defaults.string(forKey: Key.worldClockZone) ?? "America/New_York"
        runCommand = defaults.string(forKey: Key.runCommand) ?? ""
        runName = defaults.string(forKey: Key.runName) ?? ""
    }

    func contains(_ tile: HomeTile) -> Bool { tiles.contains(tile) }

    /// A tile has a text field: the Home takes the keyboard (spec HT-28).
    var hasFields: Bool { tiles.contains { HomeTile.withFields.contains($0) } }

    /// The World clock's zone, or the Mac's own when the saved name is unknown.
    var worldClockTimeZone: TimeZone { TimeZone(identifier: worldClockZone) ?? .current }

    /// Adds a tile, or moves it if it is already there, before `index` (nil: at the end) (spec HT-22).
    func place(_ tile: HomeTile, at index: Int? = nil) {
        var next = tiles
        let old = next.firstIndex(of: tile)
        next.removeAll { $0 == tile }
        var target = min(index ?? next.count, next.count)
        if let old, let index, old < index { target = max(min(index - 1, next.count), 0) }
        next.insert(tile, at: max(target, 0))
        if next != tiles { tiles = next }
    }

    func remove(_ tile: HomeTile) {
        tiles.removeAll { $0 == tile }
    }

    /// The default tiles (spec HT-17).
    func reset() {
        tiles = HomeTile.defaults
    }
}
