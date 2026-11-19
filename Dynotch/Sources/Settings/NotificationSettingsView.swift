import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: NotificationService
    @ObservedObject var beeper: BeeperService
    @State private var accessibilityTrusted = NativeBannerDismisser.isTrusted
    @State private var beeperToken = ""
    @State private var appSearch = ""
    @State private var beeperHasToken = BeeperClient.hasToken
    @State private var beeperStatus = ""

    var body: some View {
        // The search stands above the form: inside it (as a row or in a section header) the
        // field did not take clicks in the notch panel.
        VStack(spacing: 0) {
            SettingsSearchField(text: $appSearch, prompt: "Search apps and websites")
                .padding(.horizontal, 20)
                .padding(.top, 10)
            form
        }
        .onAppear {
            service.refreshApps()
            accessibilityTrusted = NativeBannerDismisser.isTrusted
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityTrusted = NativeBannerDismisser.isTrusted
        }
    }

    private var form: some View {
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
                            .focusOnClick()
                            .frame(width: 160)
                        Button("Paste") {
                            beeperToken = NSPasteboard.general.string(forType: .string)?
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        }
                        .help("Paste the token from the clipboard")
                        .accessibilityLabel("Paste the token from the clipboard")
                        Button("Save") {
                            BeeperClient.setToken(beeperToken)
                            beeperToken = ""
                            beeperHasToken = BeeperClient.hasToken
                            checkBeeper()
                        }
                        .disabled(beeperToken.isEmpty)
                    }
                }
                BeeperSettingsRows(beeper: beeper)
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

            Section {
                if service.apps.isEmpty {
                    Text("The app list appears once notifications can be read.")
                        .foregroundStyle(.secondary)
                } else {
                    // A browser's sites right under it, each switchable (spec E-15b).
                    ForEach(service.apps.filter { !splitIDs.contains($0.identifier) && matchesSearch($0) }) { app in
                        NotificationSourceRow(app: app, service: service, isOn: binding(for: app))
                        ForEach(service.sources(from: app)) { site in
                            NotificationSourceRow(app: site, service: service, isOn: binding(for: site))
                                .padding(.leading, 26)
                        }
                    }
                }
            } header: {
                Text("Apps")
            }

            if service.siteApps.contains(where: { !splitIDs.contains($0.identifier) }) {
                Section {
                    ForEach(service.siteApps.filter { !splitIDs.contains($0.identifier) && matchesSearch($0) }) { app in
                        NotificationSourceRow(app: app, service: service, isOn: binding(for: app))
                    }
                } header: {
                    Text("Websites")
                } footer: {
                    Text("Notifications a browser shows for a website without its own web app, one row per site. "
                        + "A site appears here with its first notification.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GoogleChatWebSettingsSection(chatWeb: service.chatWeb)

            DynotchAlertsSection(preferences: service.preferences)

            Section {
                PeekSettingsRows(preferences: service.preferences)
                FocusToggle(preferences: service.preferences)
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
    }

    @ViewBuilder private var statusView: some View {
        switch service.status {
        case .running:
            Label("Working", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .noAccess:
            VStack(alignment: .trailing, spacing: 2) {
                Button("Grant Full Disk Access…", action: service.openFullDiskAccessSettings)
                // Shown as allowed in System Settings yet refused: macOS needs it switched again.
                Text("Already on? Switch Dynotch off and on there.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    /// Sources listed under their browser, not again on their own.
    private var splitIDs: Set<String> {
        Set(service.apps.filter { WebNotificationSource.isShared($0.identifier) }.flatMap { service.sources(from: $0) }.map(\.identifier))
    }

    private func matchesSearch(_ app: NotificationApp) -> Bool {
        appSearch.isEmpty || app.name.localizedCaseInsensitiveContains(appSearch)
            || (app.site?.localizedCaseInsensitiveContains(appSearch) ?? false)
    }

    private func binding(for app: NotificationApp) -> Binding<Bool> {
        Binding(
            get: { service.isEnabled(app) },
            set: { settings.setNotificationApp(app.identifier, enabled: $0) }
        )
    }
}

/// During a Focus only the sources allowed in their rules pop up (spec E-20).
struct FocusToggle: View {
    @ObservedObject var preferences: NotificationPreferences

    var body: some View {
        Toggle("During a Focus, pop up only the sources allowed in their rules", isOn: $preferences.respectsFocus)
        // A Focus that keeps every macOS banner away, while Dynotch shows them all (spec E-20b).
        LabeledContent("Except during the Focus") {
            TextField("Dynotch", text: $preferences.ignoredFocus)
                .multilineTextAlignment(.trailing)
                .frame(width: 140)
        }
        .disabled(!preferences.respectsFocus)
        Text("To never see macOS banners: in System Settings › Focus add a Focus with this name that allows no apps, "
            + "turn off sharing across devices and keep it on. Notifications still reach Notification Center, "
            + "so Dynotch shows every one of them.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// How many lines of a message the pop-up shows before hovering shows all of it (spec E-22b);
/// whether it shows the message at all is set per app.
private struct PeekSettingsRows: View {
    @ObservedObject var preferences: NotificationPreferences

    var body: some View {
        // Name or message is chosen per app, under each app's rules (spec E-22b).
        LabeledContent("Message lines in pop-ups") {
            HStack(spacing: 6) {
                Text("\(preferences.peekLines)")
                    .monospacedDigit()
                Stepper("", value: $preferences.peekLines, in: NotificationPreferences.peekLinesRange)
                    .labelsHidden()
            }
        }
    }
}
