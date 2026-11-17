import AppKit
import Combine

/// How one source's notifications behave (spec E-15). nil: the default.
struct NotificationRule: Codable, Equatable, Sendable {
    /// Shown instead of the app's or site's own name.
    var name: String?
    /// Close the macOS banner; default: the general setting.
    var hidesBanner: Bool?
    /// A reply field under the messages; default: none.
    var showsReply: Bool?

    var isDefault: Bool { name == nil && hidesBanner == nil && showsReply == nil }
}

/// The websites a browser shows notifications for, and the rules of every source (spec E-15).
@MainActor
final class NotificationPreferences: ObservableObject {
    private static let sitesKey = "notificationSites"
    private static let rulesKey = "notificationRules"

    /// Site (host) → the browser that showed its notifications.
    @Published private(set) var sites: [String: String] {
        didSet { defaults.set(sites, forKey: Self.sitesKey) }
    }

    @Published private(set) var rules: [String: NotificationRule] {
        didSet { if let data = try? JSONEncoder().encode(rules) { defaults.set(data, forKey: Self.rulesKey) } }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        sites = defaults.dictionary(forKey: Self.sitesKey) as? [String: String] ?? [:]
        rules = defaults.data(forKey: Self.rulesKey).flatMap { try? JSONDecoder().decode([String: NotificationRule].self, from: $0) } ?? [:]
    }

    /// A site seen for the first time joins the list (spec E-15).
    func register(site: String, browser: String) {
        if sites[site] != browser { sites[site] = browser }
    }

    func rule(for identifier: String) -> NotificationRule {
        rules[identifier] ?? NotificationRule()
    }

    func setRule(_ rule: NotificationRule, for identifier: String) {
        var cleaned = rule
        if let name = cleaned.name?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            cleaned.name = name
        } else {
            cleaned.name = nil
        }
        rules[identifier] = cleaned.isDefault ? nil : cleaned
    }

    /// Custom names, for the app catalog.
    var names: [String: String] {
        rules.compactMapValues(\.name)
    }
}

extension WebNotificationSource {
    static let sitePrefix = "web:"

    /// Names of well-known sites; others are shown by their address.
    static let siteNames: [String: String] = [
        "mail.google.com": "Gmail",
        "chat.google.com": "Google Chat",
        "calendar.google.com": "Google Calendar",
        "meet.google.com": "Google Meet",
        "web.whatsapp.com": "WhatsApp Web",
        "app.slack.com": "Slack",
        "teams.microsoft.com": "Microsoft Teams",
        "outlook.office.com": "Outlook",
        "outlook.live.com": "Outlook"
    ]

    /// Sites shown out of the box, as their web apps were before (spec E-2b).
    static let defaultSites: Set<String> = ["mail.google.com", "chat.google.com"]

    /// The source a website's notifications are listed under when no web app is installed for it.
    static func siteIdentifier(_ host: String) -> String {
        sitePrefix + host.lowercased()
    }

    static func site(fromIdentifier identifier: String) -> String? {
        identifier.hasPrefix(sitePrefix) ? String(identifier.dropFirst(sitePrefix.count)) : nil
    }

    static func displayName(forSite host: String) -> String {
        siteNames[host] ?? (host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)
    }
}

// MARK: - Sources

extension NotificationService {
    func isEnabled(_ app: NotificationApp) -> Bool {
        // Every system notice follows the one "System Settings" switch (spec E-2c).
        let key = app.isSystem ? NotificationApp.systemGroupID : app.identifier
        // A website starts out like its browser, Gmail and Google Chat start out on (spec E-15).
        var fallback = app.isDefaultEnabled
        if let site = WebNotificationSource.site(fromIdentifier: app.identifier) {
            let browser = preferences.sites[site].map { catalog.app(for: $0) }
            fallback = WebNotificationSource.defaultSites.contains(site) || browser.map(isEnabled) == true
        }
        return settings.isNotificationAppEnabled(key, default: fallback)
    }

    /// Whether the card gets a reply field (spec E-11): off unless the source's rule shows it
    /// (spec E-16b).
    func canReply(to notification: AppNotification) -> Bool {
        let app = catalog.app(for: notification.appIdentifier)
        return rule(for: app).showsReply ?? false
    }

    /// Notifications of a site get their own source: the installed web app if there is one,
    /// otherwise the site itself (spec E-2b, E-15).
    func attribute(_ notification: AppNotification) -> AppNotification {
        let resolved = resolve(notification)
        guard resolved.appIdentifier == notification.appIdentifier,
              WebNotificationSource.isShared(notification.appIdentifier), let site = notification.site
        else { return resolved }
        preferences.register(site: site, browser: notification.appIdentifier)
        return notification.with(appIdentifier: WebNotificationSource.siteIdentifier(site))
    }

    /// Websites from notifications that came before Dynotch knew about sites (still in
    /// Notification Center) are listed right away, not only with their next one (spec E-15).
    func registerSites(_ found: [(browser: String, site: String)]) {
        let pairs = apps.map { (identifier: $0.identifier, name: $0.name) }
        for (browser, site) in found
        where WebNotificationSource.resolvedIdentifier(browser, site: site, apps: pairs) == browser {
            preferences.register(site: site, browser: browser)
        }
    }

    /// Whether the macOS banner of this source's notifications is closed.
    func hidesBanner(for identifier: String) -> Bool {
        preferences.rule(for: catalogKey(identifier)).hidesBanner ?? settings.hideNativeBanners
    }

    /// The websites with notifications, as sources for the settings.
    var siteApps: [NotificationApp] {
        preferences.sites.keys
            .map { catalog.app(for: WebNotificationSource.siteIdentifier($0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The key a source's rule is stored under: system notices share one.
    func catalogKey(_ identifier: String) -> String {
        catalog.app(for: identifier).isSystem ? NotificationApp.systemGroupID : identifier
    }

    func rule(for app: NotificationApp) -> NotificationRule {
        preferences.rule(for: catalogKey(app.identifier))
    }

    func setRule(_ rule: NotificationRule, for app: NotificationApp) {
        preferences.setRule(rule, for: catalogKey(app.identifier))
        catalog.update(sites: preferences.sites, names: preferences.names)
        objectWillChange.send()
    }
}
