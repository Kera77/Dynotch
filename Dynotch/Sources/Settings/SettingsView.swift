import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let calendar: CalendarService
    let notifications: NotificationService

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings)
                .tabItem { Label("Általános", systemImage: "gearshape") }
            FeatureSettingsView(settings: settings)
                .tabItem { Label("Funkciók", systemImage: "square.grid.2x2") }
            CalendarSettingsView(settings: settings, calendar: calendar)
                .tabItem { Label("Naptár", systemImage: "calendar") }
            NotificationSettingsView(settings: settings, service: notifications)
                .tabItem { Label("Értesítések", systemImage: "bell") }
            AboutSettingsView()
                .tabItem { Label("Névjegy", systemImage: "info.circle") }
        }
        .frame(width: NotchGeometry.settingsContentSize.width, height: NotchGeometry.settingsContentSize.height)
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
