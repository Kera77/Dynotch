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
        // The settings scroll on their own; no feature switching there. Over the buttons right of
        // the notch their row scrolls, no module switch (spec TS-1).
        guard !model.isShowingSettings, !model.isShowingNotifications, !trailingZone.contains(NSEvent.mouseLocation)
        else { return false }

        let phase = Self.phase(of: event)
        // Normalize so positive = fingers moved right, regardless of "natural scrolling".
        let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        let isMomentum = !event.momentumPhase.isEmpty
        if phase == .began { gestureSwitchedFeature = false }

        if isOverDayStrip {
            // Not the rest of a swipe that just switched to the calendar: that needs a new one.
            if gestureSwitchedFeature { return true }
            return stepDays(phase: phase, isMomentum: isMomentum, fingerDeltaX: fingerDeltaX, deltaY: event.scrollingDeltaY)
        }

        if let direction = swipe.handle(
            phase: phase,
            isMomentum: isMomentum,
            fingerDeltaX: fingerDeltaX,
            deltaY: event.scrollingDeltaY
        ) {
            if closesPageBySwipe() {
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

    /// The quick toggles' page closes, back to the module under it (spec QT-6); out of an app in
    /// the Cleaner, back to its list, no module switch (spec TT-14).
    private func closesPageBySwipe() -> Bool {
        if !gestureSwitchedFeature, swipesOutOfCleanerApp() { return true }
        guard model.isShowingToggles else { return false }
        withAnimation(Self.animation) { model.setShowingToggles(false) }
        return true
    }

    /// Over the calendar's day strip a horizontal swipe steps through the days (spec K-4), and
    /// over the Days tile's on the Home (spec HT-43). Over the Calendar | Weather picker it steps
    /// the tabs instead (spec S-7).
    private var isOverDayStrip: Bool {
        if model.currentFeature == .home { return model.tileOpening == nil && MonthTilePager.shared.isOverDays }
        return model.currentFeature == .calendar && !model.isLarge && !HoveredTabs.shared.isHovering
            && MonthTilePager.shared.isOverDays && model.geometry.rect(for: model.openSize).contains(NSEvent.mouseLocation)
    }

    /// Over a tab row a swipe steps its tabs before the modules; false when not over one or at its end.
    private func stepTabs(_ offset: Int) -> Bool {
        withAnimation(Self.animation) {
            // The notifications' tabs (spec UM-8, UM-8d) and the tray's chips (spec FT-4, FT-4d).
            if model.currentFeature == .notifications, model.isOverNotificationsTabs { return model.stepNotificationsTab(by: offset) }
            if model.currentFeature == .tray, tray.isOverTabs, tray.step(by: offset) { return true }
            // The Home's month tile pages the months (spec HT-18).
            if model.currentFeature == .home, model.tileOpening == nil, MonthTilePager.shared.step(by: offset) { return true }
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

    /// The buttons right of the notch in the open panel (spec TS-1).
    var trailingZone: CGRect {
        let geometry = model.geometry
        let panel = geometry.rect(for: model.openSize)
        let side = (panel.width - geometry.notchSize.width) / 2
        return CGRect(
            x: panel.maxX - side, y: panel.maxY - geometry.menuBarHeight,
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

// MARK: - Day strip swipe (spec K-4)

extension NotchController {
    /// Moves the selected day while swiping over the day strip; the strip scrolls with it.
    func stepDays(phase: SwipeDetector.Phase, isMomentum: Bool, fingerDeltaX: CGFloat, deltaY: CGFloat) -> Bool {
        if phase == .began { dayQueue.reset() }
        let steps = dayStepper.handle(phase: phase, isMomentum: isMomentum, fingerDeltaX: fingerDeltaX, deltaY: deltaY)
        guard steps != 0 else { return dayStepper.isHorizontal }
        // One day at a time, faster while more are waiting (spec K-17).
        dayQueue.add(steps)
        drainSteps()
        return true
    }

    func stepDayOnce() {
        let step = dayQueue.next()
        guard step != 0 else { return }
        guard model.isExpanded, model.currentFeature == .calendar || model.currentFeature == .home else { return dayQueue.reset() }
        let calendarService = calendar
        guard let day = Calendar.current.date(byAdding: .day, value: step, to: calendarService.selectedDay) else { return }
        // Two weeks each way is the wall (spec K-15): the rest of the flick stops there.
        // The Days tile keeps to its five days (spec HT-46).
        let span = model.currentFeature == .home ? DaysTileContent.span : DayStripView.reach
        let clamped = DayStripView.clamped(Calendar.current.startOfDay(for: day), around: calendarService.today, span: span)
        guard clamped != calendarService.selectedDay else { return dayQueue.reset() }
        calendarService.selectedDay = clamped
        Haptics.perform(.dayStep, settings: settings)
    }
}
