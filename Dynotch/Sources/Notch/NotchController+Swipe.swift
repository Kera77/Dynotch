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
        // Over the Calendar | Weather picker it steps the tabs instead (spec S-7).
        if model.currentFeature == .calendar, !model.isLarge, !HoveredTabs.shared.isHovering,
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
            // The quick toggles' page closes, back to the module under it (spec QT-6).
            if model.isShowingToggles {
                withAnimation(Self.animation) { model.setShowingToggles(false) }
                gestureSwitchedFeature = true
                return true
            }
            if !gestureSwitchedFeature, stepTabs(direction == .next ? 1 : -1) {
                Haptics.perform(.featureSwitch, settings: settings)
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

    /// Over a tab row a swipe steps its tabs before the modules; false when not over one or at its end.
    private func stepTabs(_ offset: Int) -> Bool {
        withAnimation(Self.animation) {
            // The notifications' tabs (spec UM-8, UM-8d) and the tray's chips (spec FT-4, FT-4d).
            if model.currentFeature == .notifications, model.isOverNotificationsTabs { return model.stepNotificationsTab(by: offset) }
            if model.currentFeature == .tray, tray.isOverTabs, tray.step(by: offset) { return true }
            // Any other module's tab picker (spec S-6).
            return HoveredTabs.shared.step(by: offset)
        }
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
        // Only the fingers on the trackpad step; the run-out after letting go does not (spec M-21).
        guard event.momentumPhase.isEmpty else { return true }
        if phase == .began {
            switcherReachedEnd = false
            switcherQueue.reset()
            switcherFlick.reset()
        }
        let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        switcherFlick.add(fingerDeltaX: fingerDeltaX, deltaY: event.scrollingDeltaY, at: event.timestamp)
        // Let go while moving fast: to the end of the row that way (spec M-21).
        if phase == .ended {
            if !switcherReachedEnd, let direction = switcherFlick.flick(at: event.timestamp) { jumpToEnd(direction) }
            return true
        }
        let steps = switcherStepper.handle(
            phase: phase, isMomentum: false, fingerDeltaX: fingerDeltaX, deltaY: event.scrollingDeltaY
        )
        // At an end the rest of the gesture stops there: one bounce, no more (spec M-13).
        guard !switcherReachedEnd else { return true }
        // One module at a time, faster while more are waiting (spec M-17).
        switcherQueue.add(steps)
        drainSteps()
        return true
    }

    /// Lets the waiting module and day steps through, one at a time, until none is left.
    func drainSteps() {
        stepSwitcherOnce()
        stepDayOnce()
        guard switcherQueue.pending != 0 || dayQueue.pending != 0 else {
            stepTimer?.invalidate()
            stepTimer = nil
            return
        }
        guard stepTimer == nil else { return }
        stepTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.drainSteps() }
        }
    }

    private func stepSwitcherOnce() {
        let step = switcherQueue.next()
        guard step != 0 else { return }
        guard model.isExpanded, !model.isShowingSettings else { return switcherQueue.reset() }
        let before = model.currentFeature
        // The modules passed over are not built, only the one the swipe stops on (spec M-20).
        withAnimation(Self.animation) { model.pass(by: step) }
        if model.currentFeature != before { Haptics.perform(.featureSwitch, settings: settings) }
        if model.isAtEnd(step > 0 ? .next : .previous) {
            switcherReachedEnd = true
            switcherQueue.reset()
        }
    }

    /// A flick: straight to the first or the last module, in one slide (spec M-21).
    private func jumpToEnd(_ direction: Int) {
        switcherQueue.reset()
        switcherReachedEnd = true
        guard model.isExpanded, !model.isShowingSettings, !model.isAtEnd(direction > 0 ? .next : .previous) else { return }
        withAnimation(Self.animation) { model.pass(by: direction * settings.listedFeatures.count) }
        Haptics.perform(.featureSwitch, settings: settings)
    }

    /// Where a trackpad gesture is.
    static func phase(of event: NSEvent) -> SwipeDetector.Phase {
        if event.phase.contains(.began) { return .began }
        if event.phase.contains(.changed) { return .changed }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) { return .ended }
        return .none
    }
}
