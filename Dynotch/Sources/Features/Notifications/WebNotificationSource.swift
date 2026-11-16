import Foundation

/// Web notifications (Gmail, Google Chat…) may arrive from a browser (Zen, Chrome, Safari…) or
/// under a shared Safari "Web App" identifier instead of the web app's own. This finds the site a
/// notification came from and the installed web app for that site (spec E-2b).
enum WebNotificationSource {
    /// Site → words its web app's name contains.
    static let knownSites: [String: [String]] = [
        "mail.google.com": ["gmail"],
        "chat.google.com": ["google chat", "chat"],
        "calendar.google.com": ["calendar", "naptár"]
    ]

    /// Browsers whose notifications come from many sites.
    static let browserIdentifiers: Set<String> = [
        "com.apple.safari", "com.apple.safari.webapp",
        "app.zen-browser.zen", "org.mozilla.firefox", "com.google.chrome", "com.google.chrome.beta",
        "company.thebrowser.browser", "company.thebrowser.dia", "com.brave.browser",
        "com.microsoft.edgemac", "com.operasoftware.opera", "com.vivaldi.vivaldi"
    ]

    /// True for identifiers shared by many sites (browsers, the generic Web App host).
    static func isShared(_ identifier: String) -> Bool {
        let lowered = identifier.lowercased()
        if browserIdentifiers.contains(lowered) { return true }
        return lowered.hasPrefix("com.apple.webkit") || lowered.hasPrefix("com.apple.safari.webpush")
    }

    /// Host of the site in the record, looking at everything except the title and body (which
    /// are the message itself and could mention any domain).
    static func site(in plist: [String: Any]) -> String? {
        var strings: [String] = []
        collect(plist, into: &strings, skipping: ["titl", "body"])
        let hosts = strings.flatMap(hosts(in:))
        return hosts.first { knownSites[$0] != nil } ?? hosts.first
    }

    /// The installed web app for a site, from (identifier, name) pairs.
    static func webApp(forSite site: String, among apps: [(identifier: String, name: String)]) -> String? {
        let words = knownSites[site] ?? fallbackWords(for: site)
        let webApps = apps.filter { $0.identifier.lowercased().hasPrefix("com.apple.safari.webapp.") }
        for word in words {
            if let match = webApps.first(where: { $0.name.lowercased().contains(word) }) {
                return match.identifier
            }
        }
        return nil
    }

    /// The identifier a notification should be treated as.
    static func resolvedIdentifier(
        _ identifier: String,
        site: String?,
        apps: [(identifier: String, name: String)]
    ) -> String {
        guard isShared(identifier), let site, let webApp = webApp(forSite: site, among: apps) else {
            return identifier
        }
        return webApp
    }

    // MARK: - Private

    /// "app.slack.com" → ["slack"].
    private static func fallbackWords(for site: String) -> [String] {
        let labels = site.split(separator: ".")
        guard labels.count >= 2 else { return [site] }
        return [String(labels[labels.count - 2])]
    }

    private static func collect(_ value: Any, into strings: inout [String], skipping skipped: Set<String>) {
        switch value {
        case let string as String:
            strings.append(string)
        case let dictionary as [String: Any]:
            for (key, nested) in dictionary.sorted(by: { $0.key < $1.key }) where !skipped.contains(key) {
                collect(nested, into: &strings, skipping: skipped)
            }
        case let array as [Any]:
            for nested in array { collect(nested, into: &strings, skipping: skipped) }
        default:
            break
        }
    }

    private static func hosts(in string: String) -> [String] {
        let pattern = #"(?:[a-z0-9-]+\.)+[a-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(string.startIndex..., in: string)
        return regex.matches(in: string, range: range).compactMap { match in
            Range(match.range, in: string).map { string[$0].lowercased() }
        }
        // Bundle identifiers look like hosts too; they are never sites.
        .filter { !$0.hasPrefix("com.") && !$0.hasPrefix("group.") }
    }
}
