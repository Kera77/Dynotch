import Foundation

extension NotchViewModel {
    /// Held open until a click outside: by the settings or by typing.
    var isHeldByClick: Bool { holdsForSettings || holdsForTyping }

    /// The indicator whose drop-down is shown: the items beside the notch open on hover, also with
    /// swipe drop-downs on (spec DS-5).
    var shownIndicator: Int? { hoveredIndicator }
    /// The badge whose list is shown (spec DS-5).
    var shownBadge: String? { hoveredBadge }

    func setHovered(indicator: Int?) {
        hoveredIndicator = indicator
    }

    func setHovered(badge: String?) {
        hoveredBadge = badge
    }
}
