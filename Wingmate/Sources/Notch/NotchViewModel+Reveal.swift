import Foundation

extension NotchViewModel {
    /// Held open until a click outside: by the settings or by typing.
    var isHeldByClick: Bool { holdsForSettings || holdsForTyping }

    /// The hovered item's drop-down was opened with a swipe down (spec DS-1).
    var dropdownRevealed: Bool {
        get { reveal.isRevealed }
        set { if reveal.isRevealed != newValue { reveal.isRevealed = newValue } }
    }

    /// Drop-downs open on hover, unless they wait for a swipe (spec DS-1).
    var revealsDropdowns: Bool { !GestureSettings.shared.dropdownsOnSwipe || reveal.isRevealed }
    /// The indicator whose drop-down is shown (spec DS-1).
    var shownIndicator: Int? { revealsDropdowns ? hoveredIndicator : nil }
    /// The badge whose list is shown (spec DS-1).
    var shownBadge: String? { revealsDropdowns ? hoveredBadge : nil }

    /// Another item under the pointer waits for its own swipe (spec DS-3).
    func setHovered(indicator: Int?) {
        hoveredIndicator = indicator
        dropdownRevealed = false
    }

    func setHovered(badge: String?) {
        hoveredBadge = badge
        dropdownRevealed = false
    }
}
