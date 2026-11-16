import AppKit
import SwiftUI

extension NotchController {
    // MARK: - Swipe (spec S-1…S-4)

    func handleScroll(_ event: NSEvent) -> Bool {
        if !model.isExpanded { return handleCollapsedScroll(event) }
        // The settings scroll on their own; no feature switching there.
        guard !model.isShowingSettings, !model.isShowingNotifications else { return false }

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
        // Normalize so positive = fingers moved right, regardless of "natural scrolling".
        let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        let isMomentum = !event.momentumPhase.isEmpty
        if phase == .began { gestureSwitchedFeature = false }

        // Over the calendar's day strip a horizontal swipe steps through the days (spec K-4) —
        // but not the rest of a swipe that just switched to the calendar: that needs a new one.
        if model.currentFeature == .calendar, !model.isLarge,
           model.geometry.dayStripZone.contains(NSEvent.mouseLocation) {
            if gestureSwitchedFeature { return true }
            return stepDays(phase: phase, isMomentum: isMomentum, fingerDeltaX: fingerDeltaX, deltaY: event.scrollingDeltaY)
        }

        if let direction = swipe.handle(
            phase: phase,
            isMomentum: isMomentum,
            fingerDeltaX: fingerDeltaX,
            deltaY: event.scrollingDeltaY
        ) {
            let before = model.currentFeature
            withAnimation(Self.animation) { model.step(direction) }
            if model.currentFeature != before {
                gestureSwitchedFeature = true
                Haptics.perform(.featureSwitch, settings: settings)
            }
        }
        return swipe.isHorizontalGesture && (phase != .none || isMomentum)
    }
}
