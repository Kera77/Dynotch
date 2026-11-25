import SwiftUI

extension NotchView {
    /// The pointer is on the recording's dot (spec SH-5b).
    var isRecordingHovered: Bool {
        guard let index = model.hoveredIndicator, indicatorItems.indices.contains(index) else { return false }
        if case .recording = indicatorItems[index] { return true }
        return false
    }

    /// The closed notch's row: badges on the left, indicators on the right, the hovered one's
    /// details below (spec B-4, K-7…K-9). Also above a notification (spec E-24).
    func indicatorRow(
        hoveredIndex: Int?, notice: StickyNotice?, showsBadgeList: Bool = true
    ) -> NotchIndicatorView {
        var row = NotchIndicatorView(
            items: indicatorItems,
            leadTime: calendar.leadTime,
            notchSize: geometry.notchSize,
            hoveredIndex: hoveredIndex,
            badges: badgeFit.shown,
            hiddenBadges: badgeFit.hidden,
            hoveredBadge: model.hoveredBadge,
            notice: notice,
            // A click opens the app's notifications in the notch; nothing else (spec B-6c).
            openBadge: showBadgeNotifications,
            moveBadge: { id, index in
                withAnimation(Self.quickAnimation) { badges.moveVisible(id, toVisibleIndex: index) }
            },
            showBadgeNotifications: { _ in },
            openBadgeChat: openBadgeChat,
            dismiss: { item in
                withAnimation(Self.quickAnimation) {
                    model.hoveredIndicator = nil
                    switch item {
                    case .meeting(let event, _): calendar.dismissIndicator(event)
                    case .usage: claudeUsage.dismissIndicator()
                    case .working: break
                    case .battery(let device, _): battery.dismissWarning(for: device)
                    case .tasks: tasks.hide()
                    case .stats: stats.dismissWarnings()
                    case .music, .recording, .tools: break
                    }
                }
            },
            join: { joinedMeeting($0) },
            openTasks: { openModule(.reminders) },
            openStats: { openModule(.stats) },
            batterySamples: { battery.history.samples[$0] ?? [] },
            taskIndicator: tasks,
            badgeRows: { notifications.badgeListRows(for: $0, beeper: beeper) },
            openBadgeApp: { badges.open($0.app) },
            hideBadge: { badge, choice in withAnimation(Self.quickAnimation) { badges.hide(badge.app.bundleID, choice) } }
        )
        row.showsBadgeList = showsBadgeList
        row.stopRecording = { screenshots.stopRecording() }
        row.recordingHovered = isRecordingHovered
        row.dismissNotice = { withAnimation(Self.quickAnimation) { notices.dismiss() } }
        row.openNotice = { openNotice() }
        row.openTools = openTools
        row.music = music
        row.showsMusicPlayer = model.hoveredIndicator != nil
        row.stats = stats
        return row
    }

    /// A hovered badge's list under the row (spec B-10).
    var hoveredBadgeHeight: CGFloat? {
        guard notifications.peek == nil, let id = model.hoveredBadge,
              let badge = badgeFit.shown.first(where: { $0.id == id })
        else { return nil }
        return IndicatorLayout.badgeDropdownHeight(rows: notifications.badgeListRows(for: badge, beeper: beeper))
    }
}

extension NotchView {
    /// Meeting countdowns and the Claude usage beside the closed notch.
    var indicatorItems: [IndicatorItem] {
        let items = IndicatorItem.items(
            meetings: calendarIndicator.events, usage: claudeUsage.notchLimits, working: chatIndicator.isWorking,
            lowBatteries: battery.warnings, tasks: tasks.shown,
            music: musicIndicator.glance, stats: statsIndicator.slotValues, recording: screenshots.recordingSince,
            tools: ToolsService.shared.glance
        )
        return IndicatorItem.unfoldingUsage(
            items, hovered: model.hoveredIndicator, wings: settings.noticesBeside, toolsBeside: settings.toolsControlsBeside
        )
    }

    /// The module strip under the Wings: resting on an icon switches the Wings to it (spec MS-8).
    var stripHoverSwitch: ((FeatureID) -> Void)? {
        guard model.isPreview else { return nil }
        return { [model] feature in
            withAnimation(NotchController.animation) { model.showWings(of: feature) }
        }
    }

    /// Resting on an icon of the strip under the closed notch opens it (spec MS-7), not under the Wings.
    var stripHoverOpenDelay: Double? {
        settings.moduleStripHover && !model.isPreview ? settings.moduleStripHoverDelay : nil
    }

    /// From the Tools' hover controls: the module on the shown tab (spec TM-19).
    /// The muted microphone and Keep Awake open the quick toggles instead (spec QT-9).
    func openTools(_ tab: ToolsTab?) {
        guard let tab else { return openQuickToggles() }
        ToolsSettings.shared.tab = tab
        openModule(.tools)
    }
}
