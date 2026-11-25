import AppKit
import SwiftUI

/// Version, updates (spec U-1…U-4) and quitting.
struct AboutSettingsView: View {
    @Bindable var updates: UpdateService
    let settings: AppSettings
    let notifications: NotificationService
    @State private var copied = false

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Wingmate")
                .font(.title2.bold())
            Text("Version \(AppInfo.version) (\(AppInfo.build))")
                .foregroundStyle(.secondary)
            if let url = AppInfo.repositoryURL {
                Link("GitHub", destination: url)
            }

            VStack(spacing: 8) {
                Toggle("Install updates automatically", isOn: $updates.installsAutomatically)
                HStack(spacing: 8) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(isError ? Color.red : Color.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if case .available = updates.state {
                        Button("Install") { updates.install() }
                            .controlSize(.small)
                    } else {
                        Button("Check Now") { updates.check(installIfFound: false) }
                            .controlSize(.small)
                            .disabled(isBusy)
                    }
                }
                if let previous = updates.rollbackVersion {
                    Button("Go back to \(previous)") { updates.rollBack() }
                        .controlSize(.small)
                        .disabled(isBusy)
                        .help("Installs \(previous) again and turns off automatic updates, so it stays")
                        .accessibilityLabel("Go back to \(previous): installs it again and turns off automatic updates")
                }
            }
            .padding(.top, 14)
            .frame(maxWidth: 360)

            HStack(spacing: 12) {
                Button(copied ? "Copied ✓" : "Copy Diagnostics", action: copyDiagnostics)
                    .help("Versions, modules, permissions and the end of the logs, without any content")
                    .accessibilityLabel("Versions, modules, permissions and the end of the logs, without any content")
                Button("Quit Wingmate") { NSApp.terminate(nil) }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// For troubleshooting (spec C-7).
    private func copyDiagnostics() {
        let readable = notifications.status == .running
        var permissions: [String: Bool] = [:]
        for permission in Permission.allCases {
            permissions[permission.title] = permission.isGranted(notificationsReadable: readable) ?? false
        }
        let report = DiagnosticsLog.report(enabledModules: settings.activeFeatures.map(\.title), permissions: permissions)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        copied = true
    }

    private var isBusy: Bool {
        switch updates.state {
        case .checking, .installing: true
        default: false
        }
    }

    private var isError: Bool {
        if case .failed = updates.state { return true }
        return false
    }

    private var statusText: String {
        switch updates.state {
        case .idle:
            return updates.lastChecked == nil ? "Checks for new versions every 6 hours." : ""
        case .checking:
            return "Checking for updates…"
        case .upToDate:
            let time = updates.lastChecked?.formatted(date: .omitted, time: .shortened) ?? ""
            return "Wingmate is up to date (checked \(time))."
        case .available(let version):
            return "Version \(version) is available."
        case .installing(let version):
            return "Installing \(version)… Wingmate restarts by itself."
        case .failed(let message):
            return "Update failed: \(message)"
        }
    }
}
