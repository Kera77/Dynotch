import Foundation

/// Web notifications (Gmail, Google Chat…) may arrive from a browser (Ardia, Zen, Chrome, Safari…) or
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
        "com.ardia.browser", "app.zen-browser.zen", "org.mozilla.firefox", "com.google.chrome", "com.google.chrome.beta",
        "company.thebrowser.browser", "company.thebrowser.dia", "com.brave.browser",
        "com.microsoft.edgemac", "com.operasoftware.opera", "com.vivaldi.vivaldi"
    ]

    /// Chromium browsers (Ardia, Chrome…) post alert-style notifications from a helper,
    /// "<browser>.framework.AlertNotificationService": that is the browser itself (spec E-2e).
    static func owningApp(_ identifier: String) -> String {
        let suffix = ".framework.alertnotificationservice"
        guard identifier.lowercased().hasSuffix(suffix) else { return identifier }
        return String(identifier.dropLast(suffix.count))
    }

    /// A browser's notification while another browser is the default: left out, only the
    /// default browser's notifications are watched (spec E-2g). Installed web apps and unknown
    /// senders always pass; Safari's web push counts as Safari.
    static func isFromOtherBrowser(_ identifier: String, defaultBrowser: String?) -> Bool {
        guard let defaultBrowser = defaultBrowser?.lowercased() else { return false }
        var owner = owningApp(identifier).lowercased()
        if owner.hasPrefix("com.apple.safari.webpush") { owner = "com.apple.safari" }
        guard owner != "com.apple.safari.webapp", !isWebApp(owner), browserIdentifiers.contains(owner) else { return false }
        return owner != defaultBrowser
    }

    /// True for identifiers shared by many sites (browsers, the generic Web App host).
    static func isShared(_ identifier: String) -> Bool {
        let lowered = identifier.lowercased()
        if browserIdentifiers.contains(lowered) { return true }
        return lowered.hasPrefix("com.apple.webkit") || lowered.hasPrefix("com.apple.safari.webpush")
    }

    /// An installed web app (Safari "Add to Dock", a Chrome or Ardia app): its page closes its own
    /// notifications too, read or not (spec E-13d).
    static func isWebApp(_ identifier: String) -> Bool {
        let lowered = identifier.lowercased()
        return lowered.hasPrefix("com.apple.safari.webapp.") || lowered.hasPrefix("com.google.chrome.app.")
            || lowered.hasPrefix("com.ardia.browser.app.")
    }

    /// Host of the site in the record, looking at everything except the title and body (which
    /// are the message itself and could mention any domain).
    static func site(in plist: [String: Any]) -> String? {
        var strings: [String] = []
        collect(plist, into: &strings, skipping: ["titl", "body"])
        let hosts = strings.flatMap(hosts(in:))
        return hosts.first { knownSites[$0] != nil } ?? hosts.first
    }

    /// A conversation address in the record (not in the title or body), e.g.
    /// https://chat.google.com/dm/… or https://mail.google.com/chat/… (spec E-11b).
    static func conversationLink(in plist: [String: Any]) -> URL? {
        var strings: [String] = []
        collect(plist, into: &strings, skipping: ["titl", "body"])
        let candidates = strings.flatMap(urls(in:))
        return candidates.first(where: isConversation)
    }

    static func isConversation(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let path = url.path.lowercased() + "#" + (url.fragment ?? "").lowercased()
        if host == "chat.google.com" { return path.count > 2 }
        if host == "mail.google.com" { return path.contains("/chat") || path.contains("#chat/") }
        return false
    }

    /// The link's shape for the diagnostics log: host and path with ids masked.
    static func maskedShape(of url: URL) -> String {
        let path = (url.path + (url.fragment.map { "#" + $0 } ?? ""))
            .replacingOccurrences(of: #"[A-Za-z0-9_-]{6,}"#, with: "…", options: .regularExpression)
        return (url.host ?? "?") + path
    }

    private static func urls(in string: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        return detector.matches(in: string, range: NSRange(string.startIndex..., in: string)).compactMap(\.url)
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
        case let data as Data:
            // userInfo is often stored as a nested property list.
            if let nested = try? PropertyListSerialization.propertyList(from: data, format: nil) {
                collect(nested, into: &strings, skipping: skipped)
            }
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
