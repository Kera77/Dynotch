import AppKit

/// An app whose notifications can be shown in the notch.
struct NotificationApp: Identifiable {
    let identifier: String
    let name: String
    let url: URL?
    let icon: NSImage?

    var id: String { identifier }
    var kind: NotificationKind { NotificationKind.detect(appName: name) }
    var isDefaultEnabled: Bool { Self.isDefaultEnabled(identifier: identifier, name: name) }

    /// System Settings notices (spec E-2c): identifier part → name shown.
    static let systemSources: [(match: String, name: String)] = [
        ("btmnotificationagent", "Login Items"),
        ("softwareupdatenotification", "Software Update"),
        ("com.apple.tccd", "Privacy & Security"),
        ("com.apple.systempreferences", "System Settings")
    ]

    static func systemName(for identifier: String) -> String? {
        let lowered = identifier.lowercased()
        return systemSources.first { lowered.contains($0.match) }?.name
    }

    /// Out of the box: Beeper, the Gmail / Google Chat web apps, and System Settings notices.
    static func isDefaultEnabled(identifier: String, name: String) -> Bool {
        if systemName(for: identifier) != nil { return true }
        let identifier = identifier.lowercased()
        let name = name.lowercased()
        if identifier.contains("beeper") { return true }
        return identifier.contains("webapp") && (name.contains("gmail") || name.contains("google chat"))
    }
}

/// Resolves bundle identifiers to app names and icons (cached).
@MainActor
final class NotificationAppCatalog {
    private var cache: [String: NotificationApp] = [:]

    func app(for identifier: String) -> NotificationApp {
        if let cached = cache[identifier] { return cached }
        // System notices have no app of their own: show them as System Settings.
        let systemName = NotificationApp.systemName(for: identifier)
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
            ?? (systemName != nil ? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") : nil)
        let name = systemName
            ?? url.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
        let app = NotificationApp(
            identifier: identifier,
            name: name ?? identifier,
            url: url,
            icon: url.map { NSWorkspace.shared.icon(forFile: $0.path) }
        )
        cache[identifier] = app
        return app
    }

    func open(_ identifier: String) {
        guard let url = app(for: identifier).url else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
