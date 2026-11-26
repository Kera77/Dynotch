import SwiftUI

/// A module opened from a Home tile: which tile, and where it grew from (spec HT-11).
struct TileOpening: Equatable {
    let tile: HomeTile
    /// The module it opened: the tile's own, or a part of the Today tile's (spec HT-27).
    let feature: FeatureID
    /// The tile's place in the Home, as a share of its size: the module grows from and shrinks back to it.
    let anchor: UnitPoint
}

extension NotchViewModel {
    /// A click on a tile: its module grows from it (spec HT-11). A module that is off opens too (spec HT-10).
    /// - Parameter part: a part of a tile that opens another module (the Today tile, spec HT-27).
    func openTile(_ tile: HomeTile, part: FeatureID? = nil, anchor: UnitPoint) {
        let feature = part ?? tile.feature
        guard isExpanded, currentFeature == .home, feature != .home else { return }
        if !settings.isSwitchedOn(feature) { settings.visitingFeature = settings.hostFeature(of: feature) }
        tileOpening = TileOpening(tile: tile, feature: feature, anchor: anchor)
        DiagnosticsLog.append("home", "opened tile \(tile.rawValue) → \(feature.rawValue)")
        // Not remembered: the next opening follows the usual rules (spec HT-13).
        select(feature, remember: false, exact: true)
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
        guard let tileOpening, settings.hostFeature(of: currentFeature) != settings.hostFeature(of: tileOpening.feature)
        else { return }
        self.tileOpening = nil
    }
}
