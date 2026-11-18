import SwiftUI

/// The content of each feature in the open panel.
extension NotchView {
    @ViewBuilder
    func page(for feature: FeatureID) -> some View {
        switch feature {
        case .home:
            HomeFeatureView()
        case .calendar:
            CalendarFeatureView(service: calendar, model: model)
        case .notifications:
            NotificationsTabsView(
                service: notifications, beeper: beeper, tab: $model.notificationsTab,
                isActive: model.isExpanded && model.currentFeature == .notifications
            )
        case .calculator:
            CalculatorFeatureView(
                store: calculator, isActive: model.isExpanded && !model.isPreview && model.currentFeature == .calculator
            )
        case .notes:
            NotesFeatureView(store: notes, isActive: model.isExpanded && model.currentFeature == .notes)
        case .reminders:
            RemindersFeatureView(store: reminders, isActive: model.isExpanded && model.currentFeature == .reminders)
        case .claudeUsage:
            ClaudeUsageFeatureView(service: claudeUsage, isActive: model.isExpanded && model.currentFeature == .claudeUsage)
        case .claudeChat:
            ClaudeChatFeatureView(service: chat, isActive: model.isExpanded && model.currentFeature == .claudeChat)
        case .battery:
            BatteryFeatureView(service: battery, isActive: model.isExpanded && model.currentFeature == .battery)
        case .clipboard, .tray, .info:
            morePage(for: feature)
        }
    }

    @ViewBuilder
    private func morePage(for feature: FeatureID) -> some View {
        switch feature {
        case .clipboard:
            ClipboardFeatureView(store: clipboard, close: closeNotifications)
        case .tray:
            TrayFeatureView(store: tray)
        default:
            InfoFeatureView(geometry: geometry, screenName: model.screenName)
        }
    }

    /// The clipboard's items while its shortcut is held, or the drop zone (spec CB-3, FT-1).
    @ViewBuilder var overlayPage: some View {
        if model.isShowingSwitcher, let switcher {
            SwitcherView(
                switcher: switcher, settings: switcher.settings, notchHeight: geometry.notchSize.height,
                width: model.openSize.width
            )
        } else if model.isShowingClipboardPicker {
            ClipboardPickerView(picker: clipboardPicker, store: clipboard, notchHeight: geometry.notchSize.height)
        } else {
            TrayDropZoneView(notchHeight: geometry.notchSize.height, keep: keepInTray, airDrop: sendWithAirDrop)
        }
    }

    /// A new notification under the closed notch: the name, or its messages too (spec E-3, E-22).
    func peekView(_ notification: AppNotification, width: CGFloat) -> some View {
        let peekSize = notifications.peekSize(in: geometry)
        return NotificationPeekView(
            app: notifications.catalog.app(for: notification.appIdentifier),
            content: notifications.content(for: notification),
            notchHeight: geometry.notchSize.height,
            newCount: notifications.unseen.count,
            messages: notifications.peekShowsMessage(notification) ? notifications.peekTexts(for: notification) : [],
            lines: notifications.preferences.peekLines
        )
        .frame(width: max(width, peekSize.width), height: peekSize.height)
    }
}
