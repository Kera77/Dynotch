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
                .environment(\.mergedTabs, MergedTabs(tabs: tabs, selected: feature) { tab in model.pickTab(tab) })
        } else if let tabs = settings.mergedTabs(for: feature) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    CapsulePicker(
                        items: tabs,
                        selection: Binding(get: { feature }, set: { tab in model.pickTab(tab) }),
                        title: \.tabTitle
                    )
                    Spacer(minLength: 8)
                    // The System's Options beside its tabs, no header row of its own (spec SY-13).
                    if feature == .stats { StatsOptionsMenu(options: stats.options) }
                }
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
        case .clipboard, .tray, .info, .music, .stats, .terminal, .tools, .weather:
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
            StatsFeatureView(
                service: stats, isActive: model.isExpanded && !model.isPreview && model.currentFeature == .stats,
                showsOptions: settings.mergedTabs(for: .stats) == nil
            )
        case .tools:
            ToolsFeatureView(isActive: model.isExpanded && !model.isPreview && model.currentFeature == .tools)
        case .weather:
            WeatherFeatureView(isActive: model.isExpanded && model.currentFeature == .weather)
        case .terminal:
            TerminalFeatureView(
                store: .shared, isActive: model.isExpanded && !model.isPreview && model.currentFeature == .terminal
            )
        default:
            InfoFeatureView(geometry: geometry, screenName: model.screenName)
        }
    }

    /// The clipboard's items while its shortcut is held, or the drop zone (spec CB-3, FT-1).
    @ViewBuilder var overlayPage: some View {
        if !model.whatsNew.isEmpty {
            WhatsNewPage(releases: model.whatsNew, notchHeight: geometry.notchSize.height, done: doneWhatsNew)
        } else if let editor = model.editor {
            ScreenshotEditorView(
                editor: editor, settings: screenshots.settings, notchHeight: geometry.notchSize.height, close: closeScreenshotEditor
            )
        } else if model.showsModuleSwitcher, let switcher {
            ModuleSwitcherView(switcher: switcher.modules, notchHeight: geometry.notchSize.height, width: model.openSize.width)
        } else if model.isShowingSwitcher, let switcher {
            SwitcherView(
                switcher: switcher, settings: switcher.settings, notchHeight: geometry.notchSize.height,
                width: model.openSize.width
            )
        } else if model.isShowingClipboardPicker {
            ClipboardPickerView(picker: clipboardPicker, store: clipboard, notchHeight: geometry.notchSize.height)
        } else if model.isPreview {
            // Files dropped on the wings: tray left, AirDrop right (spec PV-14).
            WingsDropView(notchWidth: geometry.notchSize.width, keep: keepInTray, airDrop: sendWithAirDrop)
        } else {
            TrayDropZoneView(notchHeight: geometry.notchSize.height, keep: keepInTray, airDrop: sendWithAirDrop)
        }
    }

    /// A new notification under the closed notch: the name, or its messages too (spec E-3, E-22);
    /// in Wings mode beside the notch (spec PV-13).
    @ViewBuilder func peekView(_ notification: AppNotification, width: CGFloat) -> some View {
        let peekSize = notifications.peekSize(in: geometry)
        if settings.noticesBeside {
            wingsPeekView(.notification(notification))
        } else {
            standardPeek(notification, width: width, size: peekSize)
        }
    }

    private func standardPeek(_ notification: AppNotification, width: CGFloat, size peekSize: CGSize) -> some View {
        NotificationPeekView(
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

extension NotchView {
    /// All features sit side by side and the row slides (spec S-5): switching to the next feature
    /// moves the current one out to the left while the new one comes in from the right, and
    /// the other way round.
    var featureContent: some View {
        // A module left out of the list (e.g. Music opened from its cover) comes after the others (spec MU-8).
        let listed = settings.listedFeatures
        let features = Self.pages(listed: listed, current: model.currentFeature, host: settings.hostFeature(of: model.currentFeature))
        let index = features.firstIndex(of: model.currentFeature) ?? 0
        // While a swipe passes, the pages stay built around where it started (spec M-20).
        let center = model.liveCenter.flatMap { features.firstIndex(of: $0) } ?? index
        let pageWidth = model.openSize.width
        return HStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.element) { position, feature in
                // Only the module shown and its neighbours (for the swipe) are built (spec N-16).
                if abs(position - center) <= 1 {
                    page(for: feature)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .frame(width: pageWidth)
                        // A module taller than its room is cut here, the top row stays (spec N-26).
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .allowsHitTesting(feature == model.currentFeature)
                } else if model.liveCenter != nil {
                    // Passed over by a swipe: its last look, not the module itself (spec M-20).
                    PassingPage(feature: feature, snapshot: model.passing.snapshots[feature])
                        .frame(width: pageWidth)
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .allowsHitTesting(false)
                } else {
                    Color.clear.frame(width: pageWidth)
                }
            }
        }
        .frame(width: pageWidth, alignment: .leading)
        .offset(x: -CGFloat(index) * pageWidth)
        .clipped()
    }
}
