import AppKit
import SwiftUI

// MARK: - Countdown hover (spec K-8d, K-8e)

extension NotchController {
    /// Which countdown beside the closed notch is under the pointer (spec K-8d). The panel
    /// ignores the mouse while closed, so this is computed from the pointer position.
    /// The closed notch's row as it is laid out now: indicators and the badges that fit.
    struct CollapsedRow {
        let layout: IndicatorLayout
        let fit: BadgeFit
        let items: [IndicatorItem]
    }

    /// The music player has dropped down under the closed notch (spec MU-10).
    var showsMusicDropdown: Bool {
        guard let index = model.hoveredIndicator, !model.isExpanded else { return false }
        let items = collapsedRow().items
        guard items.indices.contains(index), case .music = items[index] else { return false }
        return true
    }

    func collapsedRow() -> CollapsedRow {
        let found = IndicatorItem.items(
            meetings: calendar.indicatorEvents, usage: claudeUsage.notchLimits, working: chat.isWorking,
            lowBatteries: battery.warnings, tasks: tasks.shown, music: music.indicator.glance, stats: stats.indicator.slotValues,
            recording: screenshots.recordingSince
        )
        let items = IndicatorItem.unfoldingUsage(found, hovered: model.hoveredIndicator, wings: settings.noticesBeside)
        let fit = BadgeFit.make(badges: badges.visible, items: items, room: model.badgeRoom, unfolded: model.badgesUnfolded)
        return CollapsedRow(layout: IndicatorLayout(items: items, badges: fit.shown, overflow: fit.hidden > 0), fit: fit, items: items)
    }

    func updateHoveredIndicator() {
        // A menu opened from a drop-down keeps it (spec N-22).
        guard !OpenMenus.isOpen else { return }
        let row = collapsedRow()
        let (layout, fit, items) = (row.layout, row.fit, row.items)
        let shownBadges = fit.shown
        let point = NSEvent.mouseLocation
        if notifications.peek == nil, opensTrayForDownload(at: point, layout: layout)
            || opensAnswer(at: point, layout: layout) || bringsAskerForward(at: point, layout: layout) {
            return
        }
        let besideMeeting = settings.noticesBeside && (calendar.announcement != nil || isAnnouncingTrack)
        setOverNotice((notices.notice != nil || besideMeeting) && notifications.peek == nil && model.hoveredIndicator == nil
            && noticeArea(for: layout).contains(point))
        if settings.noticesBeside, notifications.peek != nil || notices.notice != nil || besideMeeting {
            // The notice beside the notch covers the row (spec PV-13, PV-37).
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
            return
        }
        // Just after a notice was flicked away the icons under it wait (spec PV-59).
        guard !isIndicatorHoverPaused, !layout.isEmpty else {
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
            return
        }
        let geometry = model.geometry
        if notifications.peek != nil {
            // Over a notification the row stays clickable, but no details drop down (spec E-24).
            setHoveredIndicator(nil)
            setHoveredBadge(layout.badge(at: point, notchRect: geometry.notchRect).map { shownBadges[$0].id })
            return
        }
        if unfoldBadgesIfNeeded(at: point, layout: layout, hidden: fit.hidden) { return }
        // A badge being clicked or dragged stays the hovered one.
        if model.hoveredBadge != nil, NSEvent.pressedMouseButtons != 0 { return }
        let badge = layout.badge(at: point, notchRect: geometry.notchRect).map { shownBadges[$0].id }
        if badge == nil, isOnBadgeList(at: point, layout: layout, shown: shownBadges) {
            setHoveredIndicator(nil)
            return
        }
        if let badge, !settlesOn("b" + badge) { return }
        setHoveredBadge(badge)
        guard badge == nil, !items.isEmpty else {
            setHoveredIndicator(nil)
            return
        }
        hoverIndicator(at: point, items: items, layout: layout)
    }

    /// A notice beside the notch was put away less than two seconds ago (spec PV-59).
    private var isIndicatorHoverPaused: Bool {
        guard let until = indicatorHoverPausedUntil else { return false }
        if Date() < until { return true }
        indicatorHoverPausedUntil = nil
        return false
    }

    /// The indicator under the pointer, or the details it has moved down onto.
    private func hoverIndicator(at point: CGPoint, items: [IndicatorItem], layout: IndicatorLayout) {
        let geometry = model.geometry
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
            guard settlesOn("i\(slot)") else { return }
            // The cover and the stats open their module (spec MU-2, SY-7).
            // With a warning the stats drop it down with an X instead (spec SY-10).
            if let feature = items[slot].opensModule, feature != .stats || stats.indicator.warnings.isEmpty {
                openFromIndicator(feature)
                return
            }
            setHoveredIndicator(slot)
        } else {
            setHoveredIndicator(labelIndex(at: point, items: items, layout: layout))
        }
    }

    /// While one icon's details are down, passing over another icon on the way does not swap
    /// them: it takes over only once the pointer rests on it (spec N-23).
    private func settlesOn(_ target: String) -> Bool {
        let current = model.hoveredIndicator.map { "i\($0)" } ?? model.hoveredBadge.map { "b" + $0 }
        guard let current, current != target else {
            pendingHover = nil
            return true
        }
        let now = Date()
        if pendingHover?.target != target { pendingHover = (target, now) }
        guard let since = pendingHover?.since, now.timeIntervalSince(since) >= 0.3 else { return false }
        pendingHover = nil
        return true
    }

    private func openFromIndicator(_ feature: FeatureID) {
        guard settings.isEnabled(feature) else { return }
        setHoveredIndicator(nil)
        setHoveredBadge(nil)
        expand()
        withAnimation(Self.animation) { model.select(feature, remember: false, exact: true) }
    }

    /// Moving down onto the hovered badge's list keeps it open (spec B-10).
    private func isOnBadgeList(at point: CGPoint, layout: IndicatorLayout, shown: [BadgeItem]) -> Bool {
        guard let current = shown.first(where: { $0.id == model.hoveredBadge }) else { return false }
        let height = IndicatorLayout.badgeDropdownHeight(rows: notifications.badgeListRows(for: current, beeper: beeper))
        let area = layout.rect(notchRect: model.geometry.notchRect, labelHeight: height)
            .insetBy(dx: 0, dy: -NotchGeometry.topEdgeTolerance)
        return area.contains(point)
    }

    /// The item whose details under the notch are under the pointer: the hovered one (moving down
    /// onto its details keeps them), or the announced meeting, which shows without hover (spec
    /// K-8f). The panel then takes the mouse, so a click on its X or Join never reaches the app
    /// behind the notch (spec K-8i).
    private func labelIndex(at point: CGPoint, items: [IndicatorItem], layout: IndicatorLayout) -> Int? {
        // Beside the notch the announced meeting has no row under it (spec PV-67).
        let announced = settings.noticesBeside ? nil : calendar.announcement.flatMap { announcement in
            items.firstIndex { if case .meeting(let item, _) = $0 { item.id == announcement.id } else { false } }
        }
        guard let index = model.hoveredIndicator.flatMap({ items.indices.contains($0) ? $0 : nil }) ?? announced else { return nil }
        let area = layout.rect(notchRect: model.geometry.notchRect, labelHeight: items[index].labelHeight)
            .insetBy(dx: 0, dy: -NotchGeometry.topEdgeTolerance)
        return area.contains(point) ? index : nil
    }

    /// While a countdown is hovered the closed panel takes the mouse (for the X button) and the
    /// pointer is polled, since the panel then hides the mouse-moved events from the monitor.
    func setHoveredIndicator(_ index: Int?) {
        guard model.hoveredIndicator != index else { return }
        withAnimation(Self.animation) { model.hoveredIndicator = index }
        updateCollapsedInteraction()
    }

    private func setOverNotice(_ over: Bool) {
        guard isOverNotice != over else { return }
        isOverNotice = over
        updateCollapsedInteraction()
    }

    /// The app badge under the pointer can be clicked and dragged (spec B-6, B-7).
    func setHoveredBadge(_ id: String?) {
        guard model.hoveredBadge != id else { return }
        withAnimation(NotchView.quickAnimation) { model.hoveredBadge = id }
        if let id { badges.acknowledge(id) }
        updateCollapsedInteraction()
    }

    /// The "+" unfolds the hidden badges while the pointer is on it; they fold back when the
    /// pointer leaves the row left of the notch (spec B-8).
    /// - Returns: true if the badges just unfolded (the layout changes with it).
    func unfoldBadgesIfNeeded(at point: CGPoint, layout: IndicatorLayout, hidden: Int) -> Bool {
        let notch = model.geometry.notchRect
        let inRow = point.y >= notch.minY && point.y <= notch.maxY + NotchGeometry.topEdgeTolerance
        if hidden > 0, inRow, let chip = layout.overflowRange(notchRect: notch), chip.contains(point.x) {
            withAnimation(Self.animation) { model.setBadgesUnfolded(true) }
            updateCollapsedInteraction()
            return true
        }
        if model.badgesUnfolded {
            let onBadges = inRow && (layout.leftRange(notchRect: notch).map { ($0.lowerBound - 6)...$0.upperBound } ?? 0...0)
                .contains(point.x)
            if !onBadges, NSEvent.pressedMouseButtons == 0 {
                withAnimation(Self.animation) { model.setBadgesUnfolded(false) }
                updateCollapsedInteraction()
            }
        }
        return false
    }

    private func updateCollapsedInteraction() {
        guard !model.isExpanded else { return }
        let isActive = model.hoveredIndicator != nil || model.hoveredBadge != nil || model.badgesUnfolded || isOverNotice
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
        guard model.isExpanded, model.currentFeature == .calendar else { return dayQueue.reset() }
        let calendarService = calendar
        guard let day = Calendar.current.date(byAdding: .day, value: step, to: calendarService.selectedDay) else { return }
        // Two weeks each way is the wall (spec K-15): the rest of the flick stops there.
        let clamped = DayStripView.clamped(Calendar.current.startOfDay(for: day), around: calendarService.today)
        guard clamped != calendarService.selectedDay else { return dayQueue.reset() }
        calendarService.selectedDay = clamped
        Haptics.perform(.dayStep, settings: settings)
    }
}

// MARK: - Meeting announcement (spec K-8f)

extension NotchController {
    /// A two-finger swipe up over the announced meeting's name, or over a sticky notice, closes
    /// it (spec K-8f, CN-1).
    func handleCollapsedScroll(_ event: NSEvent) -> Bool {
        if handleWingsPeekScroll(event) { return true }
        guard notifications.peek == nil, !callIsShown, !model.isExpanded else { return false }
        let items = IndicatorItem.items(
            meetings: calendar.indicatorEvents, usage: claudeUsage.notchLimits, working: chat.isWorking,
            lowBatteries: battery.warnings, tasks: tasks.shown
        )
        let layout = IndicatorLayout(items: items, badges: badges.visible)
        if let handled = handleDevicePeekScroll(event) ?? handleTaskListScroll(event, items: items, layout: layout) {
            return handled
        }
        if let handled = handleBesideMeetingScroll(event) { return handled }
        let announced = calendar.announcement.flatMap { announcement in
            items.firstIndex { if case .meeting(let item, _) = $0 { item.id == announcement.id } else { false } }
        }
        guard let announced else {
            // No announcement: the notice is what is written under the notch.
            guard notices.notice != nil, noticeArea(for: layout).contains(NSEvent.mouseLocation) else { return false }
            if isSwipeUp(event) {
                foldPeekAway { notices.dismiss() }
            }
            return true
        }
        let area = layout.rect(notchRect: model.geometry.notchRect, labelHeight: items[announced].labelHeight)
            .insetBy(dx: -4, dy: -NotchGeometry.topEdgeTolerance)
        guard area.contains(NSEvent.mouseLocation) else { return false }
        if isSwipeUp(event) {
            Haptics.perform(.open, settings: settings)
            suppressIndicatorHover = true
            withAnimation(NotchView.quickAnimation) {
                calendar.dismissAnnouncement()
                setHoveredIndicator(nil)
            }
        }
        return true
    }
}

extension NotchController {
    /// A device notice is flicked away upwards (spec DV-14); nil when the pointer is not on one.
    private func handleDevicePeekScroll(_ event: NSEvent) -> Bool? {
        guard devices.current != nil, devicePeekZone.contains(NSEvent.mouseLocation) else { return nil }
        if isSwipeUp(event) {
            deviceHoverTask?.cancel()
            deviceHoverTask = nil
            foldPeekAway { devices.dismiss() }
        }
        return true
    }

    /// The announced meeting beside the notch is flicked away into it (spec PV-67); nil when it
    /// is not there.
    private func handleBesideMeetingScroll(_ event: NSEvent) -> Bool? {
        guard settings.noticesBeside, calendar.announcement != nil else { return nil }
        guard wingsPeekZone.contains(NSEvent.mouseLocation) else { return false }
        if isSwipeUp(event) { foldPeekAway { calendar.dismissAnnouncement() } }
        return true
    }
}

// MARK: - Join from the row (spec K-8k)

extension NotchController {
    /// Join opens the meeting and folds its row away, as a swipe up would; the countdown stays.
    func joinFromRow(_ event: CalendarEvent) {
        calendar.join(event)
        suppressIndicatorHover = true
        withAnimation(NotchView.quickAnimation) {
            calendar.dismissAnnouncement()
            setHoveredIndicator(nil)
        }
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

// MARK: - App badges (spec B-6)

extension NotchController {
    /// A right click on a badge opens its notifications in the notch (spec B-6b): Beeper's and
    /// Google Chat's their own tab, any other app's unopened notifications under All.
    func showNotifications(for badge: BadgeItem) {
        guard settings.isEnabled(.notifications) else {
            badges.open(badge.app)
            return
        }
        if let tab = BadgeApp.chatTab(for: badge.app) {
            openChatTab(tab)
            return
        }
        // Gmail read from Mail: its own tab (spec GM-7).
        if notifications.mail.isActive, NotificationService.isGmailApp(badge.app) {
            openChatTab(.mail)
            return
        }
        notifications.clearPeek()
        setHoveredBadge(nil)
        // The filter is in place before the panel and the list appear.
        notifications.setFocus(bundleID: badge.app.bundleID, name: badge.app.name, count: BadgeTracker.count(badge.label))
        expand()
        model.notificationsTab = .all
        model.select(.notifications)
    }
}

// MARK: - Menu bar room (spec B-8)

extension NotchController {
    /// How much room the menu bar leaves left of this display's notch.
    func applyMenuBar(_ snapshot: MenuBarSnapshot) {
        let screens = NSScreen.screens.map(\.frame)
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? model.geometry.screenFrame.maxY
        let notch = model.geometry.notchRect
        let edge = MenuBarSpace.occupiedEdge(
            on: model.geometry.screenFrame, screens: screens, primaryMaxY: primaryMaxY, notchMinX: notch.minX, snapshot: snapshot
        )
        withAnimation(Self.animation) { model.setBadgeRoom(MenuBarSpace.room(notchMinX: notch.minX, occupiedEdge: edge)) }
    }
}

// MARK: - Layout

extension NotchController {
    static func geometry(for screen: NSScreen) -> NotchGeometry {
        NotchGeometry.make(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxiliaryRightWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY
        )
    }
}
