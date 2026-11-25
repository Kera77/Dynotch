import SwiftUI

/// A module opened from a Home tile: which tile, and where it grew from (spec HT-11).
struct TileOpening: Equatable {
    let tile: HomeTile
    /// The tile's place in the Home, as a share of its size: the module grows from and shrinks back to it.
    let anchor: UnitPoint
}

extension NotchViewModel {
    /// A click on a tile: its module grows from it (spec HT-11). A module that is off opens too (spec HT-10).
    func openTile(_ tile: HomeTile, anchor: UnitPoint) {
        guard isExpanded, currentFeature == .home, tile.feature != .home else { return }
        if !settings.isSwitchedOn(tile.feature) { settings.visitingFeature = settings.hostFeature(of: tile.feature) }
        tileOpening = TileOpening(tile: tile, anchor: anchor)
        // Not remembered: the next opening follows the usual rules (spec HT-13).
        select(tile.feature, remember: false, exact: true)
    }

    /// The pinch, the swipe down or ‹ Home: the module shrinks back into its tile (spec HT-12, HT-13).
    func backToHome() {
        guard tileOpening != nil else { return }
        tileOpening = nil
        if settings.visitingFeature != nil { settings.visitingFeature = nil }
        select(.home, remember: false)
    }

    /// A swipe or a top-row icon took the panel to another module: no longer opened from a tile (spec HT-12).
    func leaveTileIfMoved() {
        guard let tileOpening, settings.hostFeature(of: currentFeature) != settings.hostFeature(of: tileOpening.tile.feature)
        else { return }
        self.tileOpening = nil
    }
}
