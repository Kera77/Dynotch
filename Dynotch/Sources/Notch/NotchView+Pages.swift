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
            NotificationsFeatureView(service: notifications, isActive: model.isExpanded && model.currentFeature == .notifications)
        case .calculator:
            CalculatorFeatureView(store: calculator)
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
        case .info:
            InfoFeatureView(geometry: geometry, screenName: model.screenName)
        }
    }
}
