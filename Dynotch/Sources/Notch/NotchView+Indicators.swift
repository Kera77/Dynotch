import SwiftUI

extension NotchView {
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
            dismiss: { item in
                withAnimation(Self.quickAnimation) {
                    model.hoveredIndicator = nil
                    switch item {
                    case .meeting(let event): calendar.dismissIndicator(event)
                    case .usage: claudeUsage.dismissIndicator()
                    case .working: break
                    case .battery(let device): battery.dismissWarning(for: device)
                    case .tasks: tasks.hide()
                    case .music, .stats: break
                    }
                }
            },
            join: { calendar.join($0) },
            openTasks: { openModule(.reminders) },
            batterySamples: { battery.history.samples[$0] ?? [] },
            taskItems: { tasks.listed },
            completeTask: { tasks.complete($0) },
            badgeRows: { notifications.badgeRows(for: $0.app) },
            openBadgeApp: { badges.open($0.app) }
        )
        row.showsBadgeList = showsBadgeList
        row.music = music
        row.stats = stats
        return row
    }

    /// A hovered badge's list under the row (spec B-10).
    var hoveredBadgeHeight: CGFloat? {
        guard notifications.peek == nil, let id = model.hoveredBadge,
              let badge = badgeFit.shown.first(where: { $0.id == id })
        else { return nil }
        return IndicatorLayout.badgeDropdownHeight(count: notifications.badgeRows(for: badge.app).count)
    }
}
