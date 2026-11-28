import AppKit
import SwiftUI

/// The one-time "Dynotch is now Wingmate" window after the takeover brought old data over: what
/// happened, and the permissions macOS wants granted again (spec RN-11).
@MainActor
enum RenameWelcome {
    private static var window: NSWindow?
    private static var closeObserver: NSObjectProtocol?

    static func showIfNeeded(notifications: NotificationService, settings: AppSettings) {
        guard UserDefaults.standard.bool(forKey: RenameMigration.welcomeKey), !AppInfo.isRunningTests else { return }
        // After the notch is up, not in the middle of launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            MainActor.assumeIsolated { show(notifications: notifications, settings: settings) }
        }
    }

    private static func show(notifications: NotificationService, settings: AppSettings) {
        guard window == nil else { return }
        let view = RenameWelcomeView(notifications: notifications, settings: settings) { window?.close() }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640), styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Wingmate"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.center()
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in
            MainActor.assumeIsolated { finish() }
        }
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DiagnosticsLog.append("rename", "welcome shown")
    }

    /// Done or closed: never again.
    private static func finish() {
        UserDefaults.standard.removeObject(forKey: RenameMigration.welcomeKey)
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        window = nil
    }
}

private struct RenameWelcomeView: View {
    var notifications: NotificationService
    var settings: AppSettings
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Dynotch is now Wingmate").font(.title2.bold())
                    Text("Same app, new name. Your settings, notes, clipboard history, chats and Claude accounts came along.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(
                "macOS ties permissions to the app's name, so grant the ones you use once more. "
                    + "A module you use needs the ones marked in orange."
            )
                .fixedSize(horizontal: false, vertical: true)
            PermissionsSettingsView(notifications: notifications, settings: settings)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                Label("If macOS asks about the keychain for your Claude accounts, click Always Allow.", systemImage: "key.fill")
                Label(
                    "When Wingmate first works with Notes, Spotify, Mail or Messages, macOS asks again: click OK.",
                    systemImage: "hand.raised.fill"
                )
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(minWidth: 440, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
    }
}
