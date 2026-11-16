import AppKit
import SwiftUI

// MARK: - Shortcuts (spec SC-1, SC-2)

extension NotchController {
    /// Opens the feature, or closes the panel if it already shows it.
    func toggle(_ feature: FeatureID, pinned: Bool) {
        guard settings.isEnabled(feature), !callIsShown else { return }
        if model.isExpanded, model.currentFeature == feature, !model.isShowingSettings, !model.isShowingNotifications {
            collapse()
            return
        }
        if model.isExpanded, model.isShowingNotifications { collapse() }
        if !model.isExpanded {
            notifications.clearPeek()
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
            expand()
        }
        withAnimation(Self.animation) { model.select(feature) }
        if pinned {
            model.isPinned = true
        } else {
            // The pointer is elsewhere: don't close before it has been on the panel.
            isHeldOpen = true
        }
        if model.wantsKeyboard {
            panel.allowsKey = true
            panel.makeKey()
        }
    }
}

// MARK: - Sticky notice (spec CN-1)

extension NotchController {
    /// Where the notice is written: under the indicators, or under the bare notch.
    func noticeArea(for layout: IndicatorLayout) -> CGRect {
        let geometry = model.geometry
        let rect = layout.isEmpty
            ? geometry.rect(for: CGSize(width: IndicatorLayout.labelWidth, height: geometry.notchSize.height + IndicatorLayout.labelHeight))
            : layout.rect(notchRect: geometry.notchRect, labelHeight: IndicatorLayout.labelHeight)
        return rect.insetBy(dx: -4, dy: -NotchGeometry.topEdgeTolerance)
    }

    /// True when this scroll event completes a two-finger swipe up.
    func isSwipeUp(_ event: NSEvent) -> Bool {
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
        return announcementSwipe.handle(phase: phase, fingerUp: fingerUp, deltaX: event.scrollingDeltaX)
    }
}
