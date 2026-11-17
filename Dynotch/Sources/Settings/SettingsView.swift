import ServiceManagement
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case features
    case calendar
    case notifications
    case badges
    case focus
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .features: "Modules"
        case .calendar: "Calendar"
        case .notifications: "Notifications"
        case .badges: "App badges"
        case .focus: "Focus"
        case .about: "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .features: "square.grid.2x2"
        case .calendar: "calendar"
        case .notifications: "bell"
        case .badges: "app.badge"
        case .focus: "cursorarrow.rays"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let calendar: CalendarService
    let notifications: NotificationService
    let badges: BadgeService
    let shortcuts: ShortcutStore
    let updates: UpdateService

    @State private var selectedTab = SettingsTab.general
    @State private var hoveredTab: SettingsTab?

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: NotchGeometry.settingsContentSize.width, height: NotchGeometry.settingsContentSize.height)
    }

    /// Icon tabs; the name of the hovered (otherwise the selected) tab is written beside them.
    private var tabBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 38, height: 26)
                            .foregroundStyle(tab == selectedTab ? Color.white : Color.primary.opacity(0.75))
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(tab == selectedTab ? Color.accentColor : .clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(tab.title)
                    .onHover { isHovering in
                        if isHovering {
                            hoveredTab = tab
                        } else if hoveredTab == tab {
                            hoveredTab = nil
                        }
                    }
                }
            }
            .padding(3)
            .background(Capsule(style: .continuous).fill(Color.primary.opacity(0.1)))

            Text((hoveredTab ?? selectedTab).title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(hoveredTab == nil || hoveredTab == selectedTab ? Color.primary : Color.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    @ViewBuilder private var content: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView(settings: settings)
        case .features:
            FeatureSettingsView(settings: settings, shortcuts: shortcuts)
        case .calendar:
            CalendarSettingsView(settings: settings, calendar: calendar)
        case .notifications:
            NotificationSettingsView(settings: settings, service: notifications)
        case .badges:
            BadgeSettingsView(service: badges)
        case .focus:
            FocusSettingsView(settings: settings)
        case .about:
            AboutSettingsView(updates: updates)
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
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
                Picker("Open settings", selection: $settings.settingsPresentation) {
                    Text("In the notch").tag(SettingsPresentation.notch)
                    Text("In a window").tag(SettingsPresentation.window)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("Rounded notch, like the Dynamic Island", isOn: $settings.roundedNotch)
                Toggle("Hide the notch over full-screen apps", isOn: $settings.hideInFullScreen)
            } footer: {
                Text("Rounded: the closed notch is a capsule that straightens out as it opens. Hidden: nothing shows "
                    + "beside the notch, not even notifications; move the pointer to the very top edge to open it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Show only a preview on hover", isOn: $settings.hoverPreview)
                LabeledContent("Open fully after") {
                    HStack {
                        Slider(value: $settings.previewDelay, in: AppSettings.previewDelayRange, step: 0.5)
                            .frame(width: 160)
                        Text(settings.previewDelay == 0 ? "Never" : "\(settings.previewDelay, specifier: "%.1f") s")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                .disabled(!settings.hoverPreview)
                Toggle("Click the preview to open fully", isOn: $settings.previewOpensOnClick)
                    .disabled(!settings.hoverPreview)
            } footer: {
                Text("The preview shows one line about the current feature. Shortcuts always open the whole panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            } footer: {
                Text("Answer, decline or reply with a text. Uses the macOS call banner (needs Accessibility); "
                    + "texting uses Messages and Contacts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Haptic feedback on the trackpad", isOn: $settings.hapticsEnabled)
            } footer: {
                Text("A light tap when the notch opens, when you swipe between features and between days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
