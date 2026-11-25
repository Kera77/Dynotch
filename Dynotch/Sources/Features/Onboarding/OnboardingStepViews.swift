import SwiftUI

/// Choose your modules: tiles in groups, each with one line and a switch (spec OB-17).
struct OnboardingModulesStep: View {
    @Bindable var settings: AppSettings

    static let groups: [(String, [FeatureID])] = [
        ("Everyday", [.calendar, .weather, .notifications, .reminders, .notes, .calculator]),
        ("Work", [.clipboard, .tray, .tools, .terminal]),
        ("AI", [.claudeChat, .claudeUsage]),
        ("Mac", [.stats, .battery, .music, .home])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Self.groups, id: \.0) { group in
                    Text(group.0).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(group.1) { feature in tile(feature) }
                    }
                }
            }
        }
        .scrollIndicators(.automatic)
    }

    private func tile(_ feature: FeatureID) -> some View {
        Toggle(isOn: Binding(
            get: { settings.isEnabled(feature) },
            set: { _ = settings.setEnabled(feature, $0) }
        )) {
            HStack(spacing: 8) {
                Image(systemName: feature.symbolName).frame(width: 18).foregroundStyle(Theme.blue)
                VStack(alignment: .leading, spacing: 0) {
                    Text(feature.title).font(.callout)
                    Text(Self.line(feature)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.fill))
    }

    /// What the module does, in a few words.
    static func line(_ feature: FeatureID) -> String {
        switch feature {
        case .home: "Clock and date"
        case .calendar: "Today and meetings"
        case .notifications: "Messages and alerts"
        case .calculator: "Quick sums"
        case .notes: "Apple Notes"
        case .reminders: "To-dos with times"
        case .claudeUsage: "Claude limits"
        case .claudeChat: "Claude and ChatGPT"
        case .battery: "Device batteries"
        case .clipboard: "Copy history"
        case .tray: "Files to keep at hand"
        case .info: "Version and display"
        case .music: "Spotify controls"
        case .stats: "CPU, memory, network"
        case .terminal: "A shell"
        case .tools: "Timer, stopwatch, pomodoro"
        case .weather: "Forecast"
        }
    }
}

/// Beside the closed notch (spec OB-18).
struct OnboardingBesideStep: View {
    @Bindable var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                OnboardingRow(symbol: "bell.badge", title: "Notifications", text: "New messages drop down under the notch.")
                OnboardingRow(symbol: "app.badge", title: "App badges", text: "Unread counts of your apps, next to the notch.")
                OnboardingRow(symbol: "timer", title: "Indicators", text: "Meeting countdown, timers, “Claude finished”.")
                OnboardingRow(symbol: "phone.fill", title: "Calls", text: "Incoming calls with answer and text back.")
                OnboardingRow(symbol: "square.grid.3x1.below.line.grid.1x2", title: "Module strip",
                              text: "Rest the pointer on the notch's bottom edge: module icons slide out.")
                OnboardingRow(symbol: "speaker.wave.2.fill", title: "Volume and brightness",
                              text: "Shown beside the notch instead of the macOS overlay.") {
                    Toggle("", isOn: $settings.hudEnabled).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }
        }
    }
}

/// Power moves (spec OB-19).
struct OnboardingPowerStep: View {
    let settings: AppSettings
    let switcher: SwitcherSettings?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let switcher { SwitcherRows(switcher: switcher) }
            OnboardingRow(symbol: "wand.and.stars", title: "Smart opening",
                          text: "The notch opens on what matters now: a meeting, a copied code, a download.")
            OnboardingRow(symbol: "command", title: "Shortcuts and pinning",
                          text: "⌘1–⌘9 in the open notch; global shortcuts per module in Settings › Modules.")
            OnboardingRow(symbol: "arrow.up.left.and.arrow.down.right", title: "Resize",
                          text: "Drag a module's bottom-right corner; it remembers the size.")
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SwitcherRows: View {
    @Bindable var switcher: SwitcherSettings

    var body: some View {
        OnboardingRow(symbol: "hand.point.up.left", title: "Three-finger swipe up",
                      text: "Pick a module from a row. If Mission Control takes this swipe, set it to four fingers in Trackpad settings.") {
            Toggle("", isOn: $switcher.moduleSwitcherOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        OnboardingRow(symbol: "rectangle.on.rectangle", title: "Window switcher",
                      text: "Swipe sideways to switch windows, with previews.") {
            Toggle("", isOn: $switcher.isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

/// Make it yours (spec OB-20).
struct OnboardingLookStep: View {
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            Picker("Design", selection: $settings.design) {
                ForEach(NotchDesign.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Picker("Open settings", selection: $settings.settingsPresentation) {
                Text("In the notch").tag(SettingsPresentation.notch)
                Text("In a window").tag(SettingsPresentation.window)
            }
            .pickerStyle(.segmented)
            Text("More in Settings › Appearance: rounded notch, opacity, the look on displays without a notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }
}

/// Permissions for the modules switched on (spec OB-21).
struct OnboardingPermissionsStep: View {
    let permissions: [Permission]

    var body: some View {
        Form {
            AccessSection(permissions: permissions, footer: "You can grant these later in Settings › Permissions.")
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

/// You're ready (spec OB-22).
struct OnboardingReadyStep: View {
    @State private var launchAtLogin = OnboardingController.launchesAtLogin

    var body: some View {
        VStack(spacing: 14) {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, enabled in OnboardingController.setLaunchAtLogin(enabled) }
            Text("Replay this tour any time in Settings › General.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
}
