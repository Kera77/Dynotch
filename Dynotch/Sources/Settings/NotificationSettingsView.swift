import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: NotificationService
    @State private var accessibilityTrusted = NativeBannerDismisser.isTrusted
    @State private var beeperToken = ""
    @State private var appSearch = ""
    @State private var beeperHasToken = BeeperClient.hasToken
    @State private var beeperStatus = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") { statusView }
                LabeledContent("Hide after") {
                    HStack {
                        Slider(value: $settings.notificationDuration, in: AppSettings.notificationDurationRange, step: 1)
                            .frame(width: 160)
                        Text("\(Int(settings.notificationDuration)) s")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section {
                LabeledContent("Beeper Desktop API") {
                    HStack {
                        SecureField(beeperHasToken ? "Token saved" : "Paste token", text: $beeperToken)
                            .frame(width: 160)
                        Button("Paste") {
                            beeperToken = NSPasteboard.general.string(forType: .string)?
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        }
                        .help("Paste the token from the clipboard")
                        Button("Save") {
                            BeeperClient.setToken(beeperToken)
                            beeperToken = ""
                            beeperHasToken = BeeperClient.hasToken
                            checkBeeper()
                        }
                        .disabled(beeperToken.isEmpty)
                    }
                }
                if !beeperStatus.isEmpty {
                    Text(beeperStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Replies")
            } footer: {
                Text("Reply to Beeper messages from the notch. In Beeper: Settings › Integrations › \"+\" next to "
                    + "Approved connections, then paste the token here. Google Chat cannot be answered this way.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Apps") {
                if service.apps.isEmpty {
                    Text("The app list appears once notifications can be read.")
                        .foregroundStyle(.secondary)
                } else {
                    SettingsSearchField(text: $appSearch, prompt: "Search apps")
                    ForEach(service.apps.filter { appSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(appSearch) }) { app in
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
                Toggle("Hide native macOS banners", isOn: $settings.hideNativeBanners)
                LabeledContent("Accessibility") {
                    if accessibilityTrusted {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Grant Access…") {
                            NativeBannerDismisser.requestTrust()
                            NativeBannerDismisser.openAccessibilitySettings()
                        }
                    }
                }
                .disabled(!settings.hideNativeBanners)
            } header: {
                Text("Native notifications")
            } footer: {
                Text("Dynotch closes the macOS banner of every notification shown in the notch; it may flash "
                    + "for a moment. To never see it, set the app's banner style to \"None\" in System Settings "
                    + "(keep \"Show in Notification Center\" on).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open macOS Notification Settings", action: service.openNotificationSettings)
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
            Label("Working", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .noAccess:
            Button("Grant Full Disk Access…", action: service.openFullDiskAccessSettings)
        case .unsupported(let message):
            Label("Can't be read", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(message)
        case .disabled:
            Text("Off (Features tab)").foregroundStyle(.secondary)
        }
    }

    private func checkBeeper() {
        guard BeeperClient.hasToken else {
            beeperStatus = ""
            return
        }
        beeperStatus = "Checking…"
        Task {
            do {
                try await BeeperClient().verify()
                beeperStatus = "Connected to Beeper ✓"
            } catch {
                beeperStatus = "\(error)"
            }
        }
    }

    private func binding(for app: NotificationApp) -> Binding<Bool> {
        Binding(
            get: { service.isEnabled(app) },
            set: { settings.setNotificationApp(app.identifier, enabled: $0) }
        )
    }
}
