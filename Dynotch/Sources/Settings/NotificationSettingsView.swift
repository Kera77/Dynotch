import SwiftUI

struct NotificationSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: NotificationService

    var body: some View {
        form
            .onAppear { service.refreshApps() }
    }

    private var form: some View {
        Form {
            AccessSection(
                permissions: [.fullDiskAccess, .accessibility],
                notificationsReadable: service.status == .running,
                footer: accessFooter
            )
            Section {
                SettingsSlider(
                    title: "Hide after", value: $settings.notificationDuration, range: AppSettings.notificationDurationRange, step: 1
                ) { "\(Int($0)) s" }
            } footer: {
                Text("Beeper, Google Chat and Gmail are set in Settings › Chats.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Closed until opened, each with its own search (spec SD-2).
            CollapsibleListSection(title: "Apps", count: listedApps.count, prompt: "Search apps") { search in
                if service.apps.isEmpty {
                    Text("The app list appears once notifications can be read.")
                        .foregroundStyle(.secondary)
                }
                // A browser's sites right under it, each switchable (spec E-15b).
                ForEach(listedApps.filter { matches($0, search) }) { app in
                    NotificationSourceRow(app: app, service: service, isOn: binding(for: app))
                    ForEach(service.sources(from: app).filter { ChatSourceKind.of($0) == nil }) { site in
                        NotificationSourceRow(app: site, service: service, isOn: binding(for: site))
                            .padding(.leading, 26)
                    }
                }
            }

            if !listedSites.isEmpty {
                CollapsibleListSection(
                    title: "Websites", count: listedSites.count, prompt: "Search websites",
                    footer: "Notifications a browser shows for a website without its own web app, one row per site. "
                        + "A site appears here with its first notification."
                ) { search in
                    ForEach(listedSites.filter { matches($0, search) }) { app in
                        NotificationSourceRow(app: app, service: service, isOn: binding(for: app))
                    }
                }
            }

            DynotchAlertsSection(preferences: service.preferences)

            Section {
                // Under the notch or in its line, with or without Wings (spec PV-66).
                Picker("Small notices", selection: $settings.noticePlacement) {
                    ForEach(NoticePlacement.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                PeekSettingsRows(preferences: service.preferences)
                FocusToggle(preferences: service.preferences)
                Toggle("Hide native macOS banners", isOn: $settings.hideNativeBanners)
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

    /// Why notifications can't be read when access alone is not the reason; what Accessibility is for.
    private var accessFooter: String {
        switch service.status {
        case .noAccess: "Already on in System Settings? Switch Dynotch off and on there. Accessibility hides the native banners."
        case .unsupported(let message): "Can't be read: \(message)"
        case .disabled: "Notifications are off (Modules page)."
        case .running: "Full Disk Access reads the notifications; Accessibility hides the native banners."
        }
    }

    /// Sources listed under their browser, not again on their own.
    private var splitIDs: Set<String> {
        Set(service.apps.filter { WebNotificationSource.isShared($0.identifier) }.flatMap { service.sources(from: $0) }.map(\.identifier))
    }

    /// Chats are set in Settings › Chats (spec SD-6).
    private var listedApps: [NotificationApp] {
        service.apps.filter { !splitIDs.contains($0.identifier) && ChatSourceKind.of($0) == nil }
    }

    private var listedSites: [NotificationApp] {
        service.siteApps.filter { !splitIDs.contains($0.identifier) && ChatSourceKind.of($0) == nil }
    }

    private func matches(_ app: NotificationApp, _ search: String) -> Bool {
        settingsSearchMatches(search, app.name, app.site)
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
