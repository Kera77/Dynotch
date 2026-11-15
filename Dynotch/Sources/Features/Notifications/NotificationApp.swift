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

    /// Out of the box: Beeper, and the Gmail / Google Chat web apps.
    static func isDefaultEnabled(identifier: String, name: String) -> Bool {
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
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
        let name = url.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
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
