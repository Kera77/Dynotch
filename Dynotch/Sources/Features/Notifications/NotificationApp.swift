import AppKit

/// An app whose notifications can be shown in the notch.
struct NotificationApp: Identifiable {
    let identifier: String
    let name: String
    let url: URL?
    let icon: NSImage?
    /// A notice of macOS itself: all of them are switched together as "System Settings".
    var isSystem = false
    /// The website this source stands for, if it is one (spec E-15).
    var site: String?

    func renamed(_ name: String) -> NotificationApp {
        var copy = NotificationApp(identifier: identifier, name: name, url: url, icon: icon)
        copy.isSystem = isSystem
        copy.site = site
        return copy
    }

    var id: String { identifier }
    var kind: NotificationKind { NotificationKind.detect(appName: name) }
    var isDefaultEnabled: Bool { isSystem || Self.isDefaultEnabled(identifier: identifier, name: name) }

    /// The one switch for every system notice (spec E-2c).
    static let systemGroupID = "dynotch.system-settings"
    static let systemGroupName = "System Settings"

    /// A notice of macOS itself: a known system source, or an Apple service that is not an app
    /// (it has no application to open).
    static func isSystem(identifier: String, hasApplication: Bool) -> Bool {
        if identifier == systemGroupID || systemName(for: identifier) != nil { return true }
        let lowered = identifier.lowercased()
        return !hasApplication && (lowered.hasPrefix("com.apple.") || lowered.hasPrefix("_system_center_"))
    }

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
    /// Site → browser, for the sources of websites (spec E-15).
    private var sites: [String: String] = [:]
    /// Names the user gave sources.
    private var names: [String: String] = [:]

    func update(sites: [String: String], names: [String: String]) {
        guard sites != self.sites || names != self.names else { return }
        self.sites = sites
        self.names = names
        cache.removeAll()
    }

    func app(for identifier: String) -> NotificationApp {
        if let cached = cache[identifier] { return cached }
        var app = WebNotificationSource.site(fromIdentifier: identifier).map { siteApp(identifier: identifier, site: $0) }
            ?? installedApp(for: identifier)
        if let name = names[identifier] { app = app.renamed(name) }
        cache[identifier] = app
        return app
    }

    /// A website's notifications, shown with its browser's icon.
    private func siteApp(identifier: String, site: String) -> NotificationApp {
        let browser = sites[site].flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        var app = NotificationApp(
            identifier: identifier, name: WebNotificationSource.displayName(forSite: site),
            url: browser, icon: browser.map { NSWorkspace.shared.icon(forFile: $0.path) }
        )
        app.site = site
        return app
    }

    private func installedApp(for identifier: String) -> NotificationApp {
        // System notices have no app of their own: show them as System Settings.
        let ownURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
        let isSystem = NotificationApp.isSystem(identifier: identifier, hasApplication: ownURL != nil)
        // System notices have no app of their own: show them as System Settings.
        let url = isSystem ? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") : ownURL
        let systemName = isSystem ? (NotificationApp.systemName(for: identifier) ?? NotificationApp.systemGroupName) : nil
        let name = systemName
            ?? url.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
        var app = NotificationApp(
            identifier: identifier,
            name: name ?? identifier,
            url: url,
            icon: url.map { NSWorkspace.shared.icon(forFile: $0.path) }
        )
        app.isSystem = isSystem
        return app
    }

    /// Opens the app, or a website in the browser in use (spec E-2f).
    func open(_ identifier: String) {
        let app = app(for: identifier)
        if let site = app.site, let page = URL(string: "https://\(site)") {
            ActiveBrowser.shared.open(page)
            return
        }
        guard let url = app.url else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
