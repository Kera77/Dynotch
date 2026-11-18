import AppKit
import SwiftUI

extension NotchController {
    // MARK: - Swipe (spec S-1…S-4)

    func handleScroll(_ event: NSEvent) -> Bool {
        if !model.isExpanded { return handleCollapsedScroll(event) }
        // Over the feature icons a swipe only moves the icons; a click switches (spec M-9).
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
            // In the notifications a swipe steps through the tabs first (spec UM-8).
            if model.currentFeature == .notifications, !gestureSwitchedFeature,
               withAnimation(Self.animation, { model.stepNotificationsTab(by: direction == .next ? 1 : -1) }) {
                return true
            }
            // In the tray a swipe steps between the tray and the folders first (spec FT-4).
            if model.currentFeature == .tray, !gestureSwitchedFeature,
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
        let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        let steps = switcherStepper.handle(
            phase: phase, isMomentum: !event.momentumPhase.isEmpty, fingerDeltaX: fingerDeltaX, deltaY: event.scrollingDeltaY
        )
        if steps != 0 {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { model.scrollSwitcher(by: steps) }
            Haptics.perform(.dayStep, settings: settings)
        }
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
