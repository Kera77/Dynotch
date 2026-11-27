import AppKit
import SwiftUI

extension NotchController {
    /// The usage dropped down for a new session is flicked back up (spec CS-7); nil when it is
    /// not down or the pointer is not on it.
    func handleUsagePopupScroll(_ event: NSEvent, items: [IndicatorItem], layout: IndicatorLayout) -> Bool? {
        guard notices.sessions.popupShown, notices.notice == nil,
              let index = items.firstIndex(where: { if case .usage = $0 { true } else { false } })
        else { return nil }
        let area = layout.rect(notchRect: model.geometry.notchRect, labelHeight: items[index].labelHeight)
            .insetBy(dx: -4, dy: -NotchGeometry.topEdgeTolerance)
        guard area.contains(NSEvent.mouseLocation) else { return nil }
        if isSwipeUp(event) {
            Haptics.perform(.open, settings: settings)
            suppressIndicatorHover = true
            withAnimation(NotchView.quickAnimation) {
                notices.sessions.closePopup()
                setHoveredIndicator(nil)
            }
        }
        return true
    }
}
