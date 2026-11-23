import Foundation

extension NotchViewModel {
    func step(_ direction: NavigationDirection) {
        step(by: direction == .next ? 1 : -1)
    }

    /// Typing in the terminal keeps the notch open with the pointer outside (spec TE-9).
    var holdsForTerminal: Bool {
        currentFeature == .terminal && !isPreview && TerminalStore.shared.typedRecently
    }
}
