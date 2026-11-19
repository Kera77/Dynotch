import SwiftUI

/// The content of each feature in the open panel.
extension NotchView {
    /// The pages side by side: a merged module's tab right after its host, any other unlisted one at the end
    /// (spec MU-8, MG-2).
    static func pages(listed: [FeatureID], current: FeatureID, host: FeatureID) -> [FeatureID] {
        guard !listed.contains(current) else { return listed }
        guard host != current, let index = listed.firstIndex(of: host) else { return listed + [current] }
        var pages = listed
        pages[index] = current
        return pages
    }

    /// A module, under the tabs of a merged module (spec MG-2).
    @ViewBuilder
    func page(for feature: FeatureID) -> some View {
        if let tabs = settings.mergedTabs(for: feature), tabs[0] == .claudeChat {
            // The AI module's header has room for the tabs, beside its buttons on the right.
            modulePage(for: feature)
                .environment(\.mergedTabs, MergedTabs(tabs: tabs, selected: feature) { tab in model.select(tab, exact: true) })
        } else if let tabs = settings.mergedTabs(for: feature) {
            VStack(alignment: .leading, spacing: 6) {
                CapsulePicker(
                    items: tabs,
                    selection: Binding(get: { feature }, set: { tab in model.select(tab, exact: true) }),
                    title: \.tabTitle
                )
                modulePage(for: feature)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            modulePage(for: feature)
        }
    }

    @ViewBuilder
    private func modulePage(for feature: FeatureID) -> some View {
        switch feature {
        case .home:
            HomeFeatureView()
        case .calendar:
            CalendarFeatureView(service: calendar, model: model)
        case .notifications:
            NotificationsTabsView(
                service: notifications, beeper: beeper, mail: notifications.mail, tab: $model.notificationsTab,
                isActive: model.isExpanded && model.currentFeature == .notifications,
                onHoverTabs: { [model] in model.isOverNotificationsTabs = $0 }
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
        case .clipboard, .tray, .info, .music, .stats:
            morePage(for: feature)
        }
    }

    @ViewBuilder
    private func morePage(for feature: FeatureID) -> some View {
        switch feature {
        case .clipboard:
            ClipboardFeatureView(store: clipboard, close: closeNotifications)
        case .tray:
            TrayFeatureView(store: tray, edit: editScreenshot)
        case .music:
            MusicFeatureView(service: music, isActive: model.isExpanded && model.currentFeature == .music)
        case .stats:
            StatsFeatureView(service: stats, isActive: model.isExpanded && !model.isPreview && model.currentFeature == .stats)
        default:
            InfoFeatureView(geometry: geometry, screenName: model.screenName)
        }
    }

    /// The clipboard's items while its shortcut is held, or the drop zone (spec CB-3, FT-1).
    @ViewBuilder var overlayPage: some View {
        if let editor = model.editor {
            ScreenshotEditorView(
                editor: editor, settings: screenshots.settings, notchHeight: geometry.notchSize.height, close: closeScreenshotEditor
            )
        } else if model.isShowingSwitcher, let switcher {
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
