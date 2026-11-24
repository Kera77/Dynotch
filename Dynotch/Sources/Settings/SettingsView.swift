import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let calendar: CalendarService
    let notifications: NotificationService
    let badges: BadgeService
    let shortcuts: ShortcutStore
    let updates: UpdateService
    let clipboard: ClipboardStore
    let tray: TrayStore
    let beeper: BeeperService
    let devices: DeviceWatcher
    let chat: ClaudeChatService
    @Bindable var tasks: TaskIndicator
    var switcher: SwitcherSettings?
    var screenshots: ScreenshotSettings?
    var battery: BatteryService?

    /// The last page opened, kept across launches (spec SD-15).
    @AppStorage("settingsLastTab") private var selectedTab = SettingsTab.general
    @State private var search = ""
    /// The last pick was lower in the sidebar than the one before it.
    @State private var movesDown = true

    /// Sections with something to fix: a permission a module in use needs (spec C-8d).
    private var warnings: Set<SettingsTab> {
        Permission.missing(settings: settings, notificationsReadable: notifications.status == .running).isEmpty ? [] : [.permissions]
    }

    /// The sidebar's selection; notes the direction before the section changes.
    private var selection: Binding<SettingsTab> {
        Binding(get: { selectedTab }, set: { tab in
            let order = SettingsTab.allCases
            movesDown = (order.firstIndex(of: tab) ?? 0) >= (order.firstIndex(of: selectedTab) ?? 0)
            selectedTab = tab
        })
    }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selected: selection, search: $search, warnings: warnings)
            Divider()
            // The new section swims in from below or above, as the sidebar runs (spec C-10).
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(selectedTab)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: movesDown ? .bottom : .top)),
                    removal: .opacity
                ))
                .clipped()
        }
        .animation(Motion.quick, value: selectedTab)
        .acceptsReorderDrops()
        .frame(width: NotchGeometry.settingsContentSize.width, height: NotchGeometry.settingsContentSize.height)
    }

    @ViewBuilder private var content: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView(settings: settings, devices: devices, chat: chat, tasks: tasks, battery: battery)
        case .appearance:
            AppearanceSettingsView(settings: settings)
        case .features:
            FeatureSettingsView(settings: settings, shortcuts: shortcuts, switcher: switcher)
        case .calendar:
            CalendarSettingsView(settings: settings, calendar: calendar)
        case .notifications:
            NotificationSettingsView(settings: settings, service: notifications)
        case .chats:
            ChatSettingsView(settings: settings, service: notifications, beeper: beeper)
        case .badges:
            BadgeSettingsView(service: badges)
        case .clipboard:
            ClipboardSettingsView(clipboard: clipboard)
        case .tray:
            TraySettingsView(tray: tray)
        case .focus:
            FocusSettingsView(settings: settings)
        case .switcher:
            if let switcher { SwitcherSettingsView(settings: switcher) }
        case .screenshots:
            if let screenshots { ScreenshotSettingsView(settings: screenshots) }
        case .tools:
            ToolsSettingsView()
        case .menuBar:
            MenuBarSettingsView(spacers: MenuBarSpacerService.shared)
        case .permissions:
            PermissionsSettingsView(notifications: notifications, settings: settings)
        case .about:
            AboutSettingsView(updates: updates, settings: settings, notifications: notifications)
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    var devices: DeviceWatcher
    let chat: ClaudeChatService
    @Bindable var tasks: TaskIndicator
    var battery: BatteryService?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?
    @State private var claudeHook = ClaudeHook.isInstalled()
    @State private var questionHook = ClaudeQuestionHook.isInstalled()
    @State private var codexHook = CodexHook.isInstalled()
    @State private var claudeHookError: String?

    var body: some View {
        Form {
            AccessSection(
                permissions: settings.callsEnabled ? [.accessibility, .contacts] : [.accessibility],
                footer: "Accessibility: the volume keys and the call banner. Contacts: caller names and texting back."
            )
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Section {
                Toggle("Volume and brightness next to the notch", isOn: $settings.hudEnabled)
            } footer: {
                Text("Replaces the macOS volume and brightness overlay (needs Accessibility). Option-Shift: finer steps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Incoming calls in the notch", isOn: $settings.callsEnabled)
                Toggle("Keep the Phone app in the Dock during calls", isOn: $settings.keepsPhoneInDock)
                    .disabled(!settings.callsEnabled)
            } footer: {
                Text("Answer, decline or reply with a text. Uses the macOS call banner (needs Accessibility); "
                    + "texting uses Messages and Contacts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            DeviceSettingsSection(devices: devices)
            // Under the devices, not Notifications (spec SD-7).
            if let battery { LowBatterySettingsSection(battery: battery) }
            Section {
                Toggle("Haptic feedback on the trackpad", isOn: $settings.hapticsEnabled)
            } footer: {
                Text("A light tap when the notch opens, when you swipe between features and between days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Tasks counter next to the notch", isOn: $tasks.isEnabled)
                Picker("Its × hides it for", selection: $tasks.snooze) {
                    ForEach(TaskSnooze.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .disabled(!tasks.isEnabled)
            } header: {
                Text("Tasks")
            } footer: {
                Text("Today's reminders (and overdue ones); when there are none, every open one. Click it to open "
                    + "Reminders. After the × it comes back sooner when a task is added.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            AISettingsSection(chat: chat)
            Section {
                Toggle("AI usage indicator next to the notch", isOn: $settings.claudeRingVisible)
                Toggle("Notify above 70% (again every 10%)", isOn: $settings.claudeUsageAlerts)
            } header: {
                Text("AI usage")
            } footer: {
                Text("Uses the Claude Code login from the keychain; macOS asks for permission the first time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Tell me when Claude Code finishes a task", isOn: $claudeHook)
                    .onChange(of: claudeHook) { _, enabled in
                        setClaudeHook(enabled)
                    }
                Toggle("Tell me when Codex (ChatGPT) finishes", isOn: $codexHook)
                    .onChange(of: codexHook) { _, enabled in setCodexHook(enabled) }
                Toggle("Tell me when Claude Code asks a question", isOn: $questionHook)
                    .onChange(of: questionHook) { _, enabled in
                        setQuestionHook(enabled)
                    }
                if let claudeHookError {
                    Text(claudeHookError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Adds hooks to ~/.claude/settings.json (a backup is kept), in the terminal and in VS Code alike. "
                    + "\"Finished\" stays under the notch until you swipe it up; a question or permission request goes once "
                    + "answered, and hovering it brings the app forward.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                SettingsSlider(title: "Close delay", value: $settings.closeDelay, range: AppSettings.closeDelayRange, step: 0.1) {
                    String(format: "%.1f s", $0)
                }
            } footer: {
                Text("How long the notch stays open after the pointer leaves it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func setClaudeHook(_ enabled: Bool) {
        guard enabled != ClaudeHook.isInstalled() else { return }
        do {
            try ClaudeHook.setInstalled(enabled)
            claudeHookError = nil
        } catch {
            claudeHookError = "Couldn't change ~/.claude/settings.json: \(error.localizedDescription)"
            claudeHook = ClaudeHook.isInstalled()
        }
    }

    private func setCodexHook(_ enabled: Bool) {
        guard enabled != CodexHook.isInstalled() else { return }
        do {
            try CodexHook.setInstalled(enabled)
            claudeHookError = nil
        } catch {
            claudeHookError = "Couldn't change ~/.codex/hooks.json: \(error.localizedDescription)"
            codexHook = CodexHook.isInstalled()
        }
    }

    private func setQuestionHook(_ enabled: Bool) {
        guard enabled != ClaudeQuestionHook.isInstalled() else { return }
        do {
            try ClaudeQuestionHook.setInstalled(enabled)
            claudeHookError = nil
        } catch {
            claudeHookError = "Couldn't change ~/.claude/settings.json: \(error.localizedDescription)"
            questionHook = ClaudeQuestionHook.isInstalled()
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Focus follows mouse

/// AutoRaise-style focus, without raising (spec F-1…F-6).
private struct FocusSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            AccessSection(permissions: [.accessibility])
            Section {
                Toggle("Focus follows mouse", isOn: $settings.focusFollowsMouse)
                SettingsSlider(
                    title: "Delay before switching", value: $settings.focusDelay, range: AppSettings.focusDelayRange, step: 0.05
                ) { "\(Int($0 * 1000)) ms" }
                .disabled(!settings.focusFollowsMouse)
            }
            Section("What it does") {
                VStack(alignment: .leading, spacing: 6) {
                    bullet("The app under the pointer gets the keyboard focus once the pointer rests on its window.")
                    bullet("Windows are never raised: a window covering part of another stays in front.")
                    bullet("Nothing happens over the menu bar, the Dock, menus, floating windows or the desktop.")
                    bullet("It waits while a mouse button is held, and while you type in a Dynotch panel.")
                    bullet("Switching between windows of the same app needs Accessibility access.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•")
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Calendar

private struct CalendarSettingsView: View {
    @Bindable var settings: AppSettings
    var calendar: CalendarService

    var body: some View {
        Form {
            AccessSection(
                permissions: [.calendar],
                footer: "Every calendar of the macOS Calendar app is shown. For Google or Outlook calendars, add "
                    + "the account in System Settings › Internet Accounts.",
                grants: [.calendar: { calendar.access == .notDetermined ? calendar.requestAccess() : calendar.openPrivacySettings() }]
            )

            Section {
                Toggle("Meeting countdown next to the notch", isOn: $settings.calendarAlertEnabled)
                LabeledContent("Show before start") {
                    HStack(spacing: 6) {
                        TextField("", value: $settings.calendarLeadMinutes, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 44)
                        Text("min")
                            .foregroundStyle(.secondary)
                        Stepper("", value: $settings.calendarLeadMinutes, in: AppSettings.calendarLeadRange)
                            .labelsHidden()
                    }
                }
                .disabled(!settings.calendarAlertEnabled)
            } footer: {
                Text("Counts down to the start (red in the last 3 minutes), then shows the time left in the meeting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            WeatherSettingsSection()
        }
        .formStyle(.grouped)
    }
}
