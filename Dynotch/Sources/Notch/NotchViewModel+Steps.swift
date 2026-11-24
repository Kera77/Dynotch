import Foundation

extension NotchViewModel {
    /// How many feature icons fit left of the notch in the open panel.
    var switcherVisibleCount: Int {
        // The row's left side, less its margins (14 at the edge, 8 before the notch).
        let room = (openSize.width - geometry.notchSize.width) / 2 - 22
        return FeatureSwitcher.visibleCount(for: room)
    }

    func step(_ direction: NavigationDirection) {
        step(by: direction == .next ? 1 : -1)
    }

    /// The current module is the last (`.next`) or the first (`.previous`) one (spec M-13).
    func isAtEnd(_ direction: NavigationDirection) -> Bool {
        let features = settings.listedFeatures
        guard let index = features.firstIndex(of: settings.hostFeature(of: currentFeature)) else { return true }
        return direction == .next ? index == features.count - 1 : index == 0
    }

    /// Typing in the terminal keeps the notch open with the pointer outside (spec TE-9).
    var holdsForTerminal: Bool {
        currentFeature == .terminal && !isPreview && TerminalStore.shared.typedRecently
    }
}

extension NotchViewModel {
    /// A merged module's tab picked by hand: shown now and on every opening until the next pick (spec MG-10).
    func pickTab(_ tab: FeatureID) {
        settings.chooseTab(tab, of: settings.hostFeature(of: tab))
        select(tab, exact: true)
    }
}
