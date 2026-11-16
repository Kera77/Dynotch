import AppKit
import SwiftUI

// MARK: - Countdown hover (spec K-8d, K-8e)

extension NotchController {
    /// Which countdown beside the closed notch is under the pointer (spec K-8d). The panel
    /// ignores the mouse while closed, so this is computed from the pointer position.
    func updateHoveredIndicator() {
        let items = IndicatorItem.items(meetings: calendar.indicatorEvents, usage: claudeUsage.notchLimits)
        let shownBadges = badges.visible
        let layout = IndicatorLayout(items: items, badges: shownBadges)
        guard !layout.isEmpty, notifications.peek == nil else {
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
            return
        }
        let geometry = model.geometry
        let point = NSEvent.mouseLocation
        // A badge being clicked or dragged stays the hovered one.
        if model.hoveredBadge != nil, NSEvent.pressedMouseButtons != 0 { return }
        let badge = layout.badge(at: point, notchRect: geometry.notchRect).map { shownBadges[$0].id }
        setHoveredBadge(badge)
        guard badge == nil, !items.isEmpty else {
            setHoveredIndicator(nil)
            return
        }
        if suppressIndicatorHover {
            let area = layout.rect(notchRect: geometry.notchRect, labelHeight: IndicatorLayout.labelHeight)
                .insetBy(dx: -4, dy: -NotchGeometry.topEdgeTolerance)
            if area.contains(point) {
                setHoveredIndicator(nil)
                return
            }
            suppressIndicatorHover = false
        }
        if let slot = layout.slot(at: point, notchRect: geometry.notchRect) {
            setHoveredIndicator(slot)
        } else if let hovered = model.hoveredIndicator, items.indices.contains(hovered),
                  layout.rect(notchRect: geometry.notchRect, labelHeight: items[hovered].labelHeight)
                    .insetBy(dx: 0, dy: -NotchGeometry.topEdgeTolerance).contains(point) {
            // Moving down onto the details keeps them visible.
            return
        } else {
            setHoveredIndicator(nil)
        }
    }

    /// While a countdown is hovered the closed panel takes the mouse (for the X button) and the
    /// pointer is polled, since the panel then hides the mouse-moved events from the monitor.
    func setHoveredIndicator(_ index: Int?) {
        guard model.hoveredIndicator != index else { return }
        withAnimation(Self.animation) { model.hoveredIndicator = index }
        updateCollapsedInteraction()
    }

    /// The app badge under the pointer can be clicked and dragged (spec B-6, B-7).
    func setHoveredBadge(_ id: String?) {
        guard model.hoveredBadge != id else { return }
        withAnimation(NotchView.quickAnimation) { model.hoveredBadge = id }
        updateCollapsedInteraction()
    }

    private func updateCollapsedInteraction() {
        guard !model.isExpanded else { return }
        let isActive = model.hoveredIndicator != nil || model.hoveredBadge != nil
        panel.ignoresMouseEvents = !isActive
        if isActive {
            startHoverTimer()
        } else {
            stopHoverTimer()
        }
    }
}

// MARK: - Day strip swipe (spec K-4)

extension NotchController {
    /// Moves the selected day while swiping over the day strip; the strip scrolls with it.
    func stepDays(phase: SwipeDetector.Phase, isMomentum: Bool, fingerDeltaX: CGFloat, deltaY: CGFloat) -> Bool {
        let steps = dayStepper.handle(phase: phase, isMomentum: isMomentum, fingerDeltaX: fingerDeltaX, deltaY: deltaY)
        guard steps != 0 else { return dayStepper.isHorizontal }
        let calendarService = calendar
        if let day = Calendar.current.date(byAdding: .day, value: steps, to: calendarService.selectedDay) {
            calendarService.selectedDay = Calendar.current.startOfDay(for: day)
            Haptics.perform(.dayStep, settings: settings)
        }
        return true
    }
}

// MARK: - Meeting announcement (spec K-8f)

extension NotchController {
    /// A two-finger swipe up over the announced meeting's name closes it.
    func handleCollapsedScroll(_ event: NSEvent) -> Bool {
        guard let announcement = calendar.announcement, notifications.peek == nil else { return false }
        let items = IndicatorItem.items(meetings: calendar.indicatorEvents, usage: claudeUsage.notchLimits)
        guard let index = items.firstIndex(where: { if case .meeting(let item) = $0 { item.id == announcement.id } else { false } })
        else { return false }
        let area = IndicatorLayout(items: items, badges: badges.visible)
            .rect(notchRect: model.geometry.notchRect, labelHeight: items[index].labelHeight)
            .insetBy(dx: -4, dy: -NotchGeometry.topEdgeTolerance)
        guard area.contains(NSEvent.mouseLocation) else { return false }

        let phase: SwipeDetector.Phase
        if event.phase.contains(.began) {
            phase = .began
        } else if event.phase.contains(.changed) {
            phase = .changed
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            phase = .ended
        } else {
            phase = .none
        }
        // Positive = fingers moved up, regardless of "natural scrolling".
        let fingerUp = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
        if announcementSwipe.handle(phase: phase, fingerUp: fingerUp, deltaX: event.scrollingDeltaX) {
            suppressIndicatorHover = true
            withAnimation(NotchView.quickAnimation) {
                calendar.dismissAnnouncement()
                setHoveredIndicator(nil)
            }
        }
        return true
    }
}

// MARK: - Notification card buttons (spec E-12)

extension NotchController {
    func closeNotificationCard() {
        collapse()
    }

    func clearAllNotifications() {
        notifications.clearAll()
        collapse()
    }
}
