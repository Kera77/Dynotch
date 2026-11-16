import ServiceManagement
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case features
    case calendar
    case notifications
    case focus
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .features: "Features"
        case .calendar: "Calendar"
        case .notifications: "Notifications"
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
        case .focus: "cursorarrow.rays"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let calendar: CalendarService
    let notifications: NotificationService

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
            FeatureSettingsView(settings: settings)
        case .calendar:
            CalendarSettingsView(settings: settings, calendar: calendar)
        case .notifications:
            NotificationSettingsView(settings: settings, service: notifications)
        case .focus:
            FocusSettingsView(settings: settings)
        case .about:
            AboutSettingsView()
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

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

// MARK: - Features

private struct FeatureSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List {
                ForEach(settings.featureOrder) { feature in
                    HStack {
                        Toggle(isOn: binding(for: feature)) {
                            Label(feature.title, systemImage: feature.symbolName)
                        }
                        Spacer()
                        if AppSettings.menuBarFeatures.contains(feature) {
                            Toggle("Menu bar", isOn: menuBarBinding(for: feature))
                                .toggleStyle(.checkbox)
                                .disabled(!settings.isEnabled(feature))
                                .help("Also show \(feature.title) as a menu bar icon; off: only in the notch")
                        }
                    }
                }
                .onMove { settings.moveFeatures(from: $0, to: $1) }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Text("Drag to reorder. At least one feature must stay on. \"Menu bar\" also adds an icon to the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func menuBarBinding(for feature: FeatureID) -> Binding<Bool> {
        Binding(
            get: { settings.showsInMenuBar(feature) },
            set: { settings.setShowsInMenuBar(feature, $0) }
        )
    }

    private func binding(for feature: FeatureID) -> Binding<Bool> {
        Binding(
            get: { settings.isEnabled(feature) },
            set: { settings.setEnabled(feature, $0) }
        )
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
                Stepper(
                    value: $settings.calendarLeadMinutes,
                    in: AppSettings.calendarLeadRange
                ) {
                    LabeledContent("Show before start", value: "\(settings.calendarLeadMinutes) min")
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

// MARK: - About

private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.topthird.inset.filled")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Dynotch")
                .font(.title2.bold())
            Text("Version \(AppInfo.version) (\(AppInfo.build))")
                .foregroundStyle(.secondary)
            if let url = AppInfo.repositoryURL {
                Link("GitHub", destination: url)
            }
            Button("Quit Dynotch") { NSApp.terminate(nil) }
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
