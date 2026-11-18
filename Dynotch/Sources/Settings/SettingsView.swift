import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
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
    let tasks: TaskIndicator
    var switcher: SwitcherSettings?

    @State private var selectedTab = SettingsTab.general
    @State private var search = ""

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selected: $selectedTab, search: $search)
            Divider()
            // Changing sections slides in, like the notification tabs (spec C-10).
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(selectedTab)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .clipped()
        }
        .animation(Motion.quick, value: selectedTab)
        .frame(width: NotchGeometry.settingsContentSize.width, height: NotchGeometry.settingsContentSize.height)
    }

    @ViewBuilder private var content: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView(settings: settings, devices: devices, chat: chat, tasks: tasks)
        case .appearance:
            AppearanceSettingsView(settings: settings)
        case .features:
            FeatureSettingsView(settings: settings, shortcuts: shortcuts)
        case .calendar:
            CalendarSettingsView(settings: settings, calendar: calendar)
        case .notifications:
            NotificationSettingsView(settings: settings, service: notifications, beeper: beeper)
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
        case .permissions:
            PermissionsSettingsView(notifications: notifications)
        case .about:
            AboutSettingsView(updates: updates, settings: settings, notifications: notifications)
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var devices: DeviceWatcher
    let chat: ClaudeChatService
    @ObservedObject var tasks: TaskIndicator
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?
    @State private var claudeHook = ClaudeHook.isInstalled()
    @State private var questionHook = ClaudeQuestionHook.isInstalled()
    @State private var claudeHookError: String?

    var body: some View {
        Form {
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
                LabeledContent("Close delay") {
                    HStack {
                        Slider(
                            value: $settings.closeDelay,
                            in: AppSettings.closeDelayRange,
                            step: 0.1
                        )
                        .frame(width: 180)
                        Text(settings.closeDelay, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit()
                            .frame(width: 28, alignment: .trailing)
                        Text("s")
                            .foregroundStyle(.secondary)
                    }
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
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Focus follows mouse", isOn: $settings.focusFollowsMouse)
                LabeledContent("Delay before switching") {
                    HStack {
                        Slider(value: $settings.focusDelay, in: AppSettings.focusDelayRange, step: 0.05)
                            .frame(width: 160)
                        Text("\(Int(settings.focusDelay * 1000)) ms")
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                    }
                }
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
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendar: CalendarService

    var body: some View {
        Form {
            Section {
                LabeledContent("Access") {
                    switch calendar.access {
                    case .granted:
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .notDetermined:
                        Button("Allow") { calendar.requestAccess() }
                    case .denied:
                        Button("Open System Settings") { calendar.openPrivacySettings() }
                    }
                }
            } footer: {
                Text("Every calendar of the macOS Calendar app is shown. For Google or Outlook calendars, add "
                    + "the account in System Settings › Internet Accounts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
        }
        .formStyle(.grouped)
    }
}
