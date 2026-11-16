import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: NotificationService
    @State private var accessibilityTrusted = NativeBannerDismisser.isTrusted

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
                Toggle("Natív macOS szalagcímek elrejtése", isOn: $settings.hideNativeBanners)
                LabeledContent("Kisegítő hozzáférés") {
                    if accessibilityTrusted {
                        Label("Engedélyezve", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Engedély megadása…") {
                            NativeBannerDismisser.requestTrust()
                            NativeBannerDismisser.openAccessibilitySettings()
                        }
                    }
                }
                .disabled(!settings.hideNativeBanners)
            } header: {
                Text("Natív értesítések")
            } footer: {
                Text("A notchban megjelenő értesítések macOS-szalagcímét a Dynotch azonnal bezárja; egy pillanatra "
                    + "még felvillanhat. Ha egyáltalán nem szeretnéd látni, az appnál állítsd a szalagcím stílusát "
                    + "„Nincs”-re (az Értesítési központ maradjon bekapcsolva).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("macOS értesítési beállítások megnyitása", action: service.openNotificationSettings)
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            service.refreshApps()
            accessibilityTrusted = NativeBannerDismisser.isTrusted
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityTrusted = NativeBannerDismisser.isTrusted
        }
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
