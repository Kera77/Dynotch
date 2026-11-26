import Foundation
import Observation

/// The tiles on the Home, where they sit, their own settings and the way back (spec HT-29, HT-38, HT-40).
@MainActor
@Observable
final class HomeTileSettings {
    static let shared = HomeTileSettings()

    /// How a module opened from a tile goes back to the Home (spec HT-40).
    enum BackGesture: String, CaseIterable, Identifiable, Sendable {
        case pinch
        case swipeDown

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pinch: "Pinch"
            case .swipeDown: "Swipe down"
            }
        }
    }

    private enum Key {
        /// Before v1.7.2: the tiles in order (spec HT-23); read once into `layout`.
        static let tiles = "home.tiles"
        static let layout = "home.layout"
        static let backGesture = "home.backGesture"
        static let worldClockZone = "home.worldClockZone"
        static let runCommand = "home.runCommand"
        static let runName = "home.runName"
    }

    /// Each tile and its place (spec HT-38).
    private(set) var slots: [HomeSlot] { didSet { defaults.set(slots.map(\.saved), forKey: Key.layout) } }
    var backGesture: BackGesture { didSet { defaults.set(backGesture.rawValue, forKey: Key.backGesture) } }

    /// The tiles in reading order.
    var tiles: [HomeTile] { HomeLayout.ordered(slots).map(\.tile) }

    /// The World clock tile's time zone, an IANA name (spec HT-29).
    var worldClockZone: String { didSet { defaults.set(worldClockZone, forKey: Key.worldClockZone) } }
    /// The Run tile's command and the name it shows (spec HT-29).
    var runCommand: String { didSet { defaults.set(runCommand, forKey: Key.runCommand) } }
    var runName: String { didSet { defaults.set(runName, forKey: Key.runName) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        slots = Self.load(defaults)
        backGesture = defaults.string(forKey: Key.backGesture).flatMap(BackGesture.init(rawValue:)) ?? .pinch
        worldClockZone = defaults.string(forKey: Key.worldClockZone) ?? "America/New_York"
        runCommand = defaults.string(forKey: Key.runCommand) ?? ""
        runName = defaults.string(forKey: Key.runName) ?? ""
    }

    private static func load(_ defaults: UserDefaults) -> [HomeSlot] {
        if let saved = defaults.stringArray(forKey: Key.layout) {
            var slots: [HomeSlot] = []
            for slot in saved.compactMap(HomeSlot.init(saved:)) where !slots.contains(where: { $0.tile == slot.tile }) {
                slots = HomeLayout.put(slot.tile, row: slot.row, column: slot.column, in: slots)
            }
            return slots
        }
        return HomeLayout.slots(from: defaults.stringArray(forKey: Key.tiles).map(HomeTile.decode) ?? HomeTile.defaults)
    }

    func contains(_ tile: HomeTile) -> Bool { slots.contains { $0.tile == tile } }

    /// A tile has a text field: the Home takes the keyboard (spec HT-28).
    var hasFields: Bool { tiles.contains { HomeTile.withFields.contains($0) } }

    /// The World clock's zone, or the Mac's own when the saved name is unknown.
    var worldClockTimeZone: TimeZone { TimeZone(identifier: worldClockZone) ?? .current }

    /// Puts a tile at a place, or moves it there; tiles it covers move on (spec HT-38).
    func put(_ tile: HomeTile, row: Int, column: Int) {
        let next = HomeLayout.put(tile, row: row, column: column, in: slots)
        if Set(next) != Set(slots) { slots = next }
    }

    /// The + button and a double click: the first free place (spec HT-38).
    func add(_ tile: HomeTile) {
        guard !contains(tile) else { return }
        let spot = HomeLayout.firstFree(tile.size, in: slots)
        slots.append(HomeSlot(tile: tile, row: spot.row, column: spot.column))
    }

    func remove(_ tile: HomeTile) {
        slots.removeAll { $0.tile == tile }
    }

    /// The default tiles (spec HT-17).
    func reset() {
        slots = HomeLayout.slots(from: HomeTile.defaults)
    }
}
