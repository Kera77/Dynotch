import AppKit
import SwiftUI

/// The chat sources that have a page of their own (spec SD-6).
enum ChatSourceKind: Int, CaseIterable, Sendable {
    case beeper
    case googleChat
    case gmail

    /// Which chat a notification source is, if any: by its identifier, site or name.
    nonisolated static func of(identifier: String, name: String, site: String?) -> ChatSourceKind? {
        let lowered = name.lowercased()
        if identifier.lowercased().contains("beeper") { return .beeper }
        if site == BrowserTabBadges.chatSite || identifier.hasSuffix(BrowserTabBadges.chatSite) || lowered.contains("google chat")
            || (lowered == "chat" && identifier.lowercased().contains("webapp")) {
            return .googleChat
        }
        if site == BrowserTabBadges.gmailSite || identifier.hasSuffix(BrowserTabBadges.gmailSite) || lowered.contains("gmail") {
            return .gmail
        }
        return nil
    }

    nonisolated static func of(_ app: NotificationApp) -> ChatSourceKind? {
        of(identifier: app.identifier, name: app.name, site: app.site)
    }
}

extension NotificationService {
    /// Every chat source seen, wherever it is listed: an app, a browser's site or a website (spec SD-6).
    var chatSources: [NotificationApp] {
        var seen = Set<String>()
        return (apps + apps.flatMap(sources(from:)) + siteApps)
            .filter { ChatSourceKind.of($0) != nil && seen.insert($0.identifier).inserted }
            .sorted { (ChatSourceKind.of($0)?.rawValue ?? 0) < (ChatSourceKind.of($1)?.rawValue ?? 0) }
    }
}

/// Settings › Chats: everything Beeper, Google Chat and Gmail need, so nothing of theirs is left
/// under Notifications (spec SD-6).
struct ChatSettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: NotificationService
    @ObservedObject var beeper: BeeperService

    @State private var beeperToken = ""
    @State private var beeperHasToken = BeeperClient.hasToken
    @State private var beeperStatus = ""

    var body: some View {
        Form {
            AccessSection(
                permissions: [.fullDiskAccess, .accessibility],
                notificationsReadable: service.status == .running,
                footer: "Full Disk Access reads the notifications; Accessibility reads the Google Chat web app."
            )
            Section {
                if service.chatSources.isEmpty {
                    Text("Beeper, Google Chat and Gmail appear here with their first notification.")
                        .foregroundStyle(.secondary)
                }
                ForEach(service.chatSources) { app in
                    NotificationSourceRow(app: app, service: service, isOn: Binding(
                        get: { service.isEnabled(app) },
                        set: { settings.setNotificationApp(app.identifier, enabled: $0) }
                    ))
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Each chat's notifications in the notch, with its own rules: banner, pop-up and reply field.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            beeperSection
            GoogleChatWebSettingsSection(chatWeb: service.chatWeb)
            MailSettingsSection(settings: settings, mail: service.mail)
        }
        .formStyle(.grouped)
        .onAppear { service.refreshApps() }
    }

    private var beeperSection: some View {
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
            Text("Beeper")
        } footer: {
            Text("Reply to Beeper messages from the notch. In Beeper: Settings › Integrations › \"+\" next to "
                + "Approved connections, then paste the token here.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
}
