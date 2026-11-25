import Foundation
import Observation

/// The tiles on the Home and how to get back to it (spec HT-12, HT-23).
@MainActor
@Observable
final class HomeTileSettings {
    static let shared = HomeTileSettings()

    /// How a module opened from a tile goes back to the Home (spec HT-12).
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
        static let tiles = "home.tiles"
        static let backGesture = "home.backGesture"
    }

    private(set) var tiles: [HomeTile] { didSet { defaults.set(tiles.map(\.rawValue), forKey: Key.tiles) } }
    var backGesture: BackGesture { didSet { defaults.set(backGesture.rawValue, forKey: Key.backGesture) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tiles = defaults.stringArray(forKey: Key.tiles).map(HomeTile.decode) ?? HomeTile.defaults
        backGesture = defaults.string(forKey: Key.backGesture).flatMap(BackGesture.init(rawValue:)) ?? .pinch
    }

    func contains(_ tile: HomeTile) -> Bool { tiles.contains(tile) }

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
