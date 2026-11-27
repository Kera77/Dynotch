import AppKit
import SwiftUI

extension NotchController {
    /// A swipe up on the overdue row under the notch (or on the counter while it shows one) hides
    /// it for 30 minutes (spec R-29); nil when the pointer is not there. The list below scrolls.
    func handleOverdueScroll(_ event: NSEvent, items: [IndicatorItem], layout: IndicatorLayout) -> Bool? {
        guard notices.notice == nil, !settings.noticesBeside,
              let index = items.firstIndex(where: { if case .tasks(let count) = $0 { !count.overdue.isEmpty } else { false } })
        else { return nil }
        let area = layout.rect(notchRect: model.geometry.notchRect, labelHeight: items[index].restingLabelHeight)
            .insetBy(dx: -4, dy: -NotchGeometry.topEdgeTolerance)
        guard area.contains(NSEvent.mouseLocation), abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) else { return nil }
        if isSwipeUp(event) {
            Haptics.perform(.open, settings: settings)
            suppressIndicatorHover = true
            withAnimation(NotchView.quickAnimation) {
                tasks.snoozeOverdue()
                setHoveredIndicator(nil)
            }
        }
        return true
    }

    /// Over the tasks drop-down with its list picker a sideways swipe changes the list (spec R-19);
    /// nil when the pointer is not on it.
    func handleTaskListScroll(_ event: NSEvent, items: [IndicatorItem], layout: IndicatorLayout) -> Bool? {
        guard let index = model.hoveredIndicator, items.indices.contains(index),
              case .tasks(let count) = items[index], count.isSplit else { return nil }
        let area = layout.rect(notchRect: model.geometry.notchRect, labelHeight: items[index].labelHeight)
            .insetBy(dx: 0, dy: -NotchGeometry.topEdgeTolerance)
        guard area.contains(NSEvent.mouseLocation) else { return nil }
        let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        let phase = Self.phase(of: event)
        if let direction = taskListSwipe.handle(
            phase: phase, isMomentum: !event.momentumPhase.isEmpty, fingerDeltaX: fingerDeltaX, deltaY: event.scrollingDeltaY
        ) {
            withAnimation(Self.animation) { _ = tasks.stepList(by: direction == .next ? 1 : -1) }
        }
        // Vertical scrolling stays with the list of tasks.
        return taskListSwipe.isHorizontalGesture && (phase != .none || !event.momentumPhase.isEmpty)
    }
}
