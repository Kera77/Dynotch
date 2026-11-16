import ServiceManagement
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case features
    case calendar
    case notifications
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Általános"
        case .features: "Funkciók"
        case .calendar: "Naptár"
        case .notifications: "Értesítések"
        case .about: "Névjegy"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .features: "square.grid.2x2"
        case .calendar: "calendar"
        case .notifications: "bell"
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
                Toggle("Indítás bejelentkezéskor", isOn: $launchAtLogin)
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
                Picker("Beállítások megnyitása", selection: $settings.settingsPresentation) {
                    Text("A notchban").tag(SettingsPresentation.notch)
                    Text("Külön ablakban").tag(SettingsPresentation.window)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("Fókusz követi az egeret (ablak előrehozása nélkül)", isOn: $settings.focusFollowsMouse)
                LabeledContent("Várakozás váltás előtt") {
                    HStack {
                        Slider(value: $settings.focusDelay, in: AppSettings.focusDelayRange, step: 0.05)
                            .frame(width: 160)
                        Text("\(Int(settings.focusDelay * 1000)) ms")
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                    }
                }
                .disabled(!settings.focusFollowsMouse)
            } footer: {
                Text("Az egér alatti app kapja a billentyűzetet, de az ablak a helyén marad. "
                    + "Ugyanazon appon belüli ablakváltáshoz Kisegítő hozzáférés kell.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Fogyasztás-karika a menüsorban", isOn: $settings.claudeRingVisible)
                Toggle("Értesítés 70% felett (10%-onként újra)", isOn: $settings.claudeUsageAlerts)
            } header: {
                Text("Claude-fogyasztás")
            } footer: {
                Text("A Claude Code bejelentkezését használja a kulcskarikából; az első lekéréskor a macOS engedélyt kér.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Bezárási késleltetés") {
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
                        Text("mp")
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Ennyi idő után csukódik be a notch, miután az egér elhagyta.")
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

// MARK: - Features

private struct FeatureSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List {
                ForEach(settings.featureOrder) { feature in
                    Toggle(isOn: binding(for: feature)) {
                        Label(feature.title, systemImage: feature.symbolName)
                    }
                }
                .onMove { settings.moveFeatures(from: $0, to: $1) }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            Text("A sorrend húzással állítható. Legalább egy funkciónak bekapcsolva kell maradnia.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
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
                LabeledContent("Hozzáférés") {
                    switch calendar.access {
                    case .granted:
                        Label("Engedélyezve", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .notDetermined:
                        Button("Engedélyezés") { calendar.requestAccess() }
                    case .denied:
                        Button("Rendszerbeállítások megnyitása") { calendar.openPrivacySettings() }
                    }
                }
            } footer: {
                Text("A macOS Naptár app összes naptára látszik. Google- vagy Outlook-naptárhoz add hozzá "
                    + "a fiókot itt: Rendszerbeállítások › Internetes fiókok.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Meeting-visszaszámláló a notch mellett", isOn: $settings.calendarAlertEnabled)
                Stepper(
                    value: $settings.calendarLeadMinutes,
                    in: AppSettings.calendarLeadRange
                ) {
                    LabeledContent("Ennyivel előtte", value: "\(settings.calendarLeadMinutes) perc")
                }
                .disabled(!settings.calendarAlertEnabled)
            } footer: {
                Text("A kezdésig visszaszámol (az utolsó 3 percben pirossal), a meeting alatt a hátralévő időt mutatja.")
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
            Text("Verzió \(AppInfo.version) (\(AppInfo.build))")
                .foregroundStyle(.secondary)
            if let url = AppInfo.repositoryURL {
                Link("GitHub", destination: url)
            }
            Button("Kilépés a Dynotch-ból") { NSApp.terminate(nil) }
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
