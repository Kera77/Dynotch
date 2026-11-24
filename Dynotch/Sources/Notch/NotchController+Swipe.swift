import AppKit
import SwiftUI

extension NotchController {
    // MARK: - Swipe (spec S-1…S-4)

    func handleScroll(_ event: NSEvent) -> Bool {
        if !model.isExpanded { return handleCollapsedScroll(event) }
        // Over the feature icons a swipe switches modules, as far as it reaches (spec M-12).
        if !model.isShowingNotifications, switcherZone.contains(NSEvent.mouseLocation) {
            return scrollSwitcher(event)
        }
        // The settings scroll on their own; no feature switching there.
        guard !model.isShowingSettings, !model.isShowingNotifications else { return false }

        let phase = Self.phase(of: event)
        // Normalize so positive = fingers moved right, regardless of "natural scrolling".
        let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        let isMomentum = !event.momentumPhase.isEmpty
        if phase == .began { gestureSwitchedFeature = false }

        // Over the calendar's day strip a horizontal swipe steps through the days (spec K-4) —
        // but not the rest of a swipe that just switched to the calendar: that needs a new one.
        if model.currentFeature == .calendar, !model.isLarge,
           model.geometry.dayStripZone(panel: model.openSize).contains(NSEvent.mouseLocation) {
            if gestureSwitchedFeature { return true }
            return stepDays(phase: phase, isMomentum: isMomentum, fingerDeltaX: fingerDeltaX, deltaY: event.scrollingDeltaY)
        }

        if let direction = swipe.handle(
            phase: phase,
            isMomentum: isMomentum,
            fingerDeltaX: fingerDeltaX,
            deltaY: event.scrollingDeltaY
        ) {
            // Over the notifications' tabs a swipe steps through them first (spec UM-8, UM-8d).
            if model.currentFeature == .notifications, model.isOverNotificationsTabs, !gestureSwitchedFeature,
               withAnimation(Self.animation, { model.stepNotificationsTab(by: direction == .next ? 1 : -1) }) {
                return true
            }
            // Over the tray's tabs a swipe steps between the tray and the folders first (spec FT-4, FT-4d).
            if model.currentFeature == .tray, tray.isOverTabs, !gestureSwitchedFeature,
               withAnimation(Self.animation, { tray.step(by: direction == .next ? 1 : -1) }) {
                return true
            }
            let before = model.currentFeature
            withAnimation(Self.animation) { model.step(direction) }
            if model.currentFeature != before {
                gestureSwitchedFeature = true
                Haptics.perform(.featureSwitch, settings: settings)
            }
        }
        return swipe.isHorizontalGesture && (phase != .none || isMomentum)
    }

    /// The feature icons left of the notch in the open panel.
    var switcherZone: CGRect {
        let geometry = model.geometry
        let panel = geometry.rect(for: model.openSize)
        let side = (panel.width - geometry.notchSize.width) / 2
        return CGRect(
            x: panel.minX, y: panel.maxY - geometry.menuBarHeight,
            width: side, height: geometry.menuBarHeight + NotchGeometry.topEdgeTolerance
        )
    }

    private func scrollSwitcher(_ event: NSEvent) -> Bool {
        let phase = Self.phase(of: event)
        let isMomentum = !event.momentumPhase.isEmpty
        if phase == .began {
            switcherReachedEnd = false
            switcherThrottle.reset()
        }
        let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        let steps = switcherStepper.handle(
            phase: phase, isMomentum: isMomentum, fingerDeltaX: fingerDeltaX, deltaY: event.scrollingDeltaY
        )
        // At an end the rest of the gesture and its momentum stop there: one bounce, no more (spec M-13).
        guard !switcherReachedEnd else { return true }
        // The steps gather and switch together, at most every 0.1 s (spec M-14).
        let pending = switcherThrottle.add(steps)
        guard pending != 0 else { return true }
        let before = model.currentFeature
        withAnimation(Self.animation) { model.step(by: pending) }
        if model.currentFeature != before { Haptics.perform(.featureSwitch, settings: settings) }
        if model.isAtEnd(pending > 0 ? .next : .previous) { switcherReachedEnd = true }
        return true
    }

    /// Where a trackpad gesture is.
    static func phase(of event: NSEvent) -> SwipeDetector.Phase {
        if event.phase.contains(.began) { return .began }
        if event.phase.contains(.changed) { return .changed }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) { return .ended }
        return .none
    }
}
