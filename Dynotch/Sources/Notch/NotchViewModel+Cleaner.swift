import SwiftUI

/// The Cleaner is a page of the Stats, not a module of its own (spec TT-8…TT-10).
extension NotchViewModel {
    /// Opens the Stats with the Cleaner on it: from the Disk card, a disk tile (the Stats grow
    /// from it, spec TT-10), the top-row button or the closed notch's tick (spec TT-9, TT-13).
    func openCleaner(from tile: HomeTile? = nil) {
        guard isExpanded else { return }
        if let tile, currentFeature == .home, tileOpening == nil {
            openTile(tile, part: .stats, anchor: .center)
        } else if currentFeature != .stats {
            if !settings.isSwitchedOn(.stats) { settings.visitingFeature = settings.hostFeature(of: .stats) }
            select(.stats, remember: false, exact: true)
        }
        if isShowingSettings || isShowingToggles { select(.stats, remember: false, exact: true) }
        showsCleaner = true
        DiagnosticsLog.append("cleaner", "opened" + (tile == nil ? "" : " from a tile"))
    }

    /// ‹ Stats, the pinch or the top-row button again: back to the Stats (spec TT-8).
    func closeCleaner() {
        guard showsCleaner else { return }
        showsCleaner = false
    }

    /// Another module: the Cleaner closes; a clean in progress goes on (spec TT-8).
    func leaveCleanerIfMoved() {
        if showsCleaner, currentFeature != .stats { showsCleaner = false }
    }
}

private struct OpenCleanerKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable (HomeTile?) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Opens the Cleaner on the Stats; a tile passes itself to grow the Stats from it (spec TT-8, TT-10).
    var openCleaner: @MainActor @Sendable (HomeTile?) -> Void {
        get { self[OpenCleanerKey.self] }
        set { self[OpenCleanerKey.self] = newValue }
    }
}
