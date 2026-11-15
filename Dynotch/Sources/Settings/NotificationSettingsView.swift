import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: NotificationService

    var body: some View {
        Form {
            Section {
                LabeledContent("Állapot") { statusView }
                LabeledContent("Eltűnés ennyi idő után") {
                    HStack {
                        Slider(value: $settings.notificationDuration, in: AppSettings.notificationDurationRange, step: 1)
                            .frame(width: 160)
                        Text("\(Int(settings.notificationDuration)) mp")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section("Appok") {
                if service.apps.isEmpty {
                    Text("Az applista akkor jelenik meg, ha az értesítések olvashatók.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(service.apps) { app in
                        Toggle(isOn: binding(for: app)) {
                            HStack(spacing: 8) {
                                AppIconView(app: app, size: 18)
                                Text(app.name)
                            }
                        }
                    }
                }
            }

            Section {
                Button("macOS értesítési beállítások megnyitása", action: service.openNotificationSettings)
            } header: {
                Text("Natív macOS értesítések elrejtése")
            } footer: {
                Text("A fent bekapcsolt appoknál állítsd a szalagcím stílusát „Nincs”-re, az „Értesítési központban” "
                    + "kapcsolót pedig hagyd bekapcsolva. Így a macOS nem mutat szalagcímet, a Dynotch viszont megkapja "
                    + "az értesítést.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { service.refreshApps() }
    }

    @ViewBuilder private var statusView: some View {
        switch service.status {
        case .running:
            Label("Működik", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .noAccess:
            Button("Teljes lemezelérés megadása…", action: service.openFullDiskAccessSettings)
        case .unsupported(let message):
            Label("Nem olvasható", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(message)
        case .disabled:
            Text("Kikapcsolva (Funkciók fül)").foregroundStyle(.secondary)
        }
    }

    private func binding(for app: NotificationApp) -> Binding<Bool> {
        Binding(
            get: { service.isEnabled(app) },
            set: { settings.setNotificationApp(app.identifier, enabled: $0) }
        )
    }
}
