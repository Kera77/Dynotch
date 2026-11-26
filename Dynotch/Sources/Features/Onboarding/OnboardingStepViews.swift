import SwiftUI

/// Choose your modules: one row per module, in groups, with a switch and two or three sentences
/// about what it does (spec OB-17, OB-33). The texts live in `OnboardingModuleTexts`.
struct OnboardingModulesStep: View {
    @Bindable var settings: AppSettings

    static let groups: [(String, [FeatureID])] = [
        ("Everyday", [.calendar, .weather, .notifications, .reminders, .notes, .calculator]),
        ("Work", [.clipboard, .tray, .tools, .terminal]),
        ("AI", [.claudeChat, .claudeUsage, .claudeSessions]),
        ("Mac", [.stats, .battery, .cleaner, .music, .home])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Self.groups, id: \.0) { group in
                Text(group.0).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
                ForEach(group.1) { feature in row(feature) }
            }
        }
        .padding(.trailing, 6)
    }

    private func row(_ feature: FeatureID) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feature.symbolName)
                .font(.system(size: 15))
                .foregroundStyle(Theme.blue)
                .frame(width: 22)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title).font(.callout.weight(.semibold))
                Text(OnboardingModuleTexts.text(for: feature))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle(feature.title, isOn: Binding(
                get: { settings.isEnabled(feature) },
                set: { _ = settings.setEnabled(feature, $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.fill))
    }
}

/// Beside the closed notch (spec OB-18).
struct OnboardingBesideStep: View {
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingRow(
                symbol: "bell.badge", title: "Notifications",
                text: "New messages drop down under the notch, two senders one under the other."
            )
            OnboardingRow(
                symbol: "app.badge", title: "App badges",
                text: "Unread counts of your apps, next to the notch; click or spread two fingers to open."
            )
            OnboardingRow(symbol: "timer", title: "Indicators",
                          text: "Meeting countdown, timers, “Claude finished”, devices, system warnings.")
            OnboardingRow(symbol: "phone.fill", title: "Calls",
                          text: "Incoming calls with answer and text back; Teams meeting controls.")
            OnboardingRow(symbol: "square.grid.3x1.below.line.grid.1x2", title: "Module strip",
                          text: "Rest the pointer on the notch's bottom edge: module icons slide out.")
            OnboardingRow(symbol: "speaker.wave.2.fill", title: "Volume and brightness",
                          text: "Shown beside the notch instead of the macOS overlay.") {
                Toggle("", isOn: $settings.hudEnabled).labelsHidden().toggleStyle(.switch).controlSize(.small)
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
            Text("More in Settings › Appearance: black notifications, rounded notch, opacity, the look on displays without a notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
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
        .scrollDisabled(true)
        // A Form has no height of its own; the card fits it (spec OB-30).
        .frame(height: CGFloat(permissions.count) * 38 + 96)
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
        .padding(.vertical, 8)
    }
}
