import SwiftUI

extension NotchView {
    /// The closed notch's row: badges on the left, indicators on the right, the hovered one's
    /// details below (spec B-4, K-7…K-9). Also above a notification (spec E-24).
    func indicatorRow(hoveredIndex: Int?, notice: StickyNotice?) -> NotchIndicatorView {
        NotchIndicatorView(
            items: indicatorItems,
            leadTime: calendar.leadTime,
            notchSize: geometry.notchSize,
            hoveredIndex: hoveredIndex,
            badges: badgeFit.shown,
            hiddenBadges: badgeFit.hidden,
            hoveredBadge: model.hoveredBadge,
            notice: notice,
            // Left click: the app itself; right click: its notifications in the notch (spec B-6b).
            openBadge: { badges.open($0.app) },
            moveBadge: { id, index in
                withAnimation(Self.quickAnimation) { badges.moveVisible(id, toVisibleIndex: index) }
            },
            showBadgeNotifications: showBadgeNotifications,
            dismiss: { item in
                withAnimation(Self.quickAnimation) {
                    model.hoveredIndicator = nil
                    switch item {
                    case .meeting(let event): calendar.dismissIndicator(event)
                    case .usage: claudeUsage.dismissIndicator()
                    case .working: break
                    case .battery(let device): battery.dismissWarning(for: device)
                    case .tasks: tasks.hide()
                    }
                }
            },
            join: { calendar.join($0) },
            openTasks: { openModule(.reminders) },
            batterySamples: { battery.history.samples[$0] ?? [] },
            taskItems: { tasks.listed },
            completeTask: { tasks.complete($0) }
        )
    }
}
