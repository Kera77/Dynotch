import Foundation

extension NotchViewModel {
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
