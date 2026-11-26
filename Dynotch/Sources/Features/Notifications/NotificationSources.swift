import AppKit
import Observation

/// How one source's notifications behave (spec E-15). nil: the default.
struct NotificationRule: Codable, Equatable, Sendable {
    /// Shown instead of the app's or site's own name.
    var name: String?
    /// Close the macOS banner; default: the general setting.
    var hidesBanner: Bool?
    /// A reply field under the messages; default: none.
    var showsReply: Bool?
    /// The pop-up shows the message text too (spec E-22b); nil: the name only.
    var peekShowsMessage: Bool?
    /// Pops up while a macOS Focus is on (spec E-20d); nil: no.
    var popsUpDuringFocus: Bool?

    var isDefault: Bool {
        name == nil && hidesBanner == nil && showsReply == nil && peekShowsMessage == nil && popsUpDuringFocus == nil
    }
}

/// The websites a browser shows notifications for, and the rules of every source (spec E-15).
@MainActor
@Observable
final class NotificationPreferences {
    private static let sitesKey = "notificationSites"
    private static let rulesKey = "notificationRules"
    private static let webAppSitesKey = "notificationWebAppSites"

    /// Site (host) → the browser that showed its notifications.
    private(set) var sites: [String: String] {
        didSet { defaults.set(sites, forKey: Self.sitesKey) }
    }

    /// Sites a browser showed that have a web app of their own (Gmail, Google Chat): listed
    /// under the browser in the settings too (spec E-15b).
    private(set) var webAppSites: [String: String] {
        didSet { defaults.set(webAppSites, forKey: Self.webAppSitesKey) }
    }

    private(set) var rules: [String: NotificationRule] {
        didSet { if let data = try? JSONEncoder().encode(rules) { defaults.set(data, forKey: Self.rulesKey) } }
    }

    private let defaults: UserDefaults

    /// Notifications put off until later (spec E-19); kept while Dynotch runs.
    var snoozed: [SnoozedNotification] = []

    /// Kinds of Dynotch's own notifications turned off (spec E-25).
    private(set) var alertsOff: Set<String> {
        didSet { defaults.set(Array(alertsOff).sorted(), forKey: "dynotchAlertsOff") }
    }

    func isOn(_ alert: DynotchAlert) -> Bool { !alertsOff.contains(alert.rawValue) }

    /// v0.70 split "System" into memory, swap and the rest (spec SY-12b): whoever had it off had it
    /// off for the memory warning, so that stays off; swap starts on.
    nonisolated static func splitSystemAlert(_ off: Set<String>, defaults: UserDefaults) -> Set<String> {
        let key = "dynotchAlertsSplit"
        guard !defaults.bool(forKey: key) else { return off }
        defaults.set(true, forKey: key)
        return off.contains(DynotchAlert.system.rawValue) ? off.union([DynotchAlert.memory.rawValue]) : off
    }

    func set(_ alert: DynotchAlert, isOn: Bool) {
        if isOn { alertsOff.remove(alert.rawValue) } else { alertsOff.insert(alert.rawValue) }
    }

    /// Lines of each message in the pop-up before hovering shows all of it.
    var peekLines: Int {
        didSet { defaults.set(peekLines, forKey: "notificationPeekLines") }
    }

    static let peekLinesRange = 2...8

    init(defaults: UserDefaults) {
        self.defaults = defaults
        alertsOff = Self.splitSystemAlert(Set(defaults.stringArray(forKey: "dynotchAlertsOff") ?? []), defaults: defaults)
        peekLines = defaults.object(forKey: "notificationPeekLines") as? Int ?? 4
        sites = defaults.dictionary(forKey: Self.sitesKey) as? [String: String] ?? [:]
        webAppSites = defaults.dictionary(forKey: Self.webAppSitesKey) as? [String: String] ?? [:]
        rules = defaults.data(forKey: Self.rulesKey).flatMap { try? JSONDecoder().decode([String: NotificationRule].self, from: $0) } ?? [:]
    }

    /// A site seen for the first time joins the list (spec E-15).
    func register(site: String, browser: String) {
        if sites[site] != browser { sites[site] = browser }
    }

    func register(webAppSite site: String, browser: String) {
        if webAppSites[site] != browser { webAppSites[site] = browser }
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
        "teams.live.com": "Microsoft Teams",
        "teams.cloud.microsoft": "Microsoft Teams",
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
        // A card from the web app's sidebar: only when the web app can write there (spec GW-18, GW-19).
        if notification.sourceIdentifier == Self.chatWebSource { return chatWeb.canWrite(title: notification.title) }
        let app = catalog.app(for: notification.appIdentifier)
        return rule(for: app).showsReply ?? false
    }

    /// Notifications of a site get their own source: the installed web app if there is one,
    /// otherwise the site itself (spec E-2b, E-15).
    func attribute(_ notification: AppNotification) -> AppNotification {
        let resolved = resolve(notification)
        guard WebNotificationSource.isShared(notification.appIdentifier), let site = notification.site else { return resolved }
        guard resolved.appIdentifier == notification.appIdentifier else {
            preferences.register(webAppSite: site, browser: notification.appIdentifier)
            return resolved
        }
        preferences.register(site: site, browser: notification.appIdentifier)
        return notification.with(appIdentifier: WebNotificationSource.siteIdentifier(site))
    }

    /// Websites from notifications that came before Dynotch knew about sites (still in
    /// Notification Center) are listed right away, not only with their next one (spec E-15).
    func registerSites(_ found: [(browser: String, site: String)]) {
        let pairs = apps.map { (identifier: $0.identifier, name: $0.name) }
        for (browser, site) in found {
            if WebNotificationSource.resolvedIdentifier(browser, site: site, apps: pairs) == browser {
                preferences.register(site: site, browser: browser)
            } else if browser.lowercased() != "com.apple.safari.webapp" {
                preferences.register(webAppSite: site, browser: browser)
            }
        }
    }

    /// Whether the macOS banner of this source's notifications is closed.
    func hidesBanner(for identifier: String) -> Bool {
        preferences.rule(for: catalogKey(identifier)).hidesBanner ?? settings.hideNativeBanners
    }

    /// The sources a browser's notifications are split into (spec E-15b): each site's web app,
    /// or the site itself.
    func sources(from browser: NotificationApp) -> [NotificationApp] {
        let pairs = apps.map { (identifier: $0.identifier, name: $0.name) }
        let found = Set(preferences.sites.filter { $0.value == browser.identifier }.keys)
            .union(preferences.webAppSites.filter { $0.value == browser.identifier }.keys)
        let identifiers = found.map { site in
            let resolved = WebNotificationSource.resolvedIdentifier(browser.identifier, site: site, apps: pairs)
            return resolved == browser.identifier ? WebNotificationSource.siteIdentifier(site) : resolved
        }
        return Set(identifiers).map(catalog.app(for:))
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    var catalog: NotificationAppCatalog {
        access(keyPath: \.catalog)
        return appCatalog
    }

    /// The app catalog follows the websites and the custom names; views reading it update.
    func updateCatalog() {
        withMutation(keyPath: \.catalog) { appCatalog.update(sites: preferences.sites, names: preferences.names) }
    }

    func rule(for app: NotificationApp) -> NotificationRule {
        preferences.rule(for: catalogKey(app.identifier))
    }

    func setRule(_ rule: NotificationRule, for app: NotificationApp) {
        preferences.setRule(rule, for: catalogKey(app.identifier))
        updateCatalog()
    }
}

// MARK: - Snooze (spec E-19)

extension NotificationService {
    /// Takes the notifications out of the list until the chosen time.
    func snooze(_ notifications: [AppNotification], _ choice: SnoozeChoice) {
        let until = choice.date(from: Date())
        let ids = Set(notifications.map(\.id))
        preferences.snoozed += notifications.map { SnoozedNotification(notification: $0, until: until) }
        removeFromLists(ids)
    }

    /// Snoozed notifications whose time has come appear again.
    func releaseSnoozed(now: Date = Date()) {
        let due = preferences.snoozed.filter { $0.until <= now }
        guard !due.isEmpty else { return }
        preferences.snoozed.removeAll { $0.until <= now }
        due.forEach { bringBack($0.notification) }
    }
}

// MARK: - Focus (spec E-20d)

extension NotificationService {
    /// Whether a notification may pop up now: not while a macOS Focus is on, unless its source
    /// is allowed during a Focus, like the apps a Focus allows in System Settings.
    func popsUp(_ notification: AppNotification) -> Bool {
        guard MacFocus.current() != nil else { return true }
        return rule(for: catalog.app(for: notification.appIdentifier)).popsUpDuringFocus == true
    }
}
