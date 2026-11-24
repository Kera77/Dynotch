import AppKit

/// Unread counts from the titles of the Gmail and Google Chat tabs open in the default browser
/// (spec B-2b, B-2c): "Inbox (9) - …" → 9. Only those tabs' addresses and titles are read,
/// nothing is logged but the counts.
enum BrowserTabBadges {
    /// Browsers whose tabs AppleScript can read, and the name of a tab's title there; Zen and
    /// Firefox have no such dictionary (spec B-2c).
    static let scriptable: [String: String] = [
        "com.ardia.browser": "title", "com.google.chrome": "title", "com.google.chrome.beta": "title",
        "company.thebrowser.browser": "title", "com.brave.browser": "title", "com.microsoft.edgemac": "title",
        "com.vivaldi.vivaldi": "title", "com.apple.safari": "name"
    ]

    /// The default browser if its tabs can be read.
    static func browser(defaultBrowser: String?) -> (id: String, titleKey: String)? {
        guard let id = defaultBrowser, let key = scriptable[id.lowercased()] else { return nil }
        return (id, key)
    }
    static let gmailSite = "mail.google.com"
    static let chatSite = "chat.google.com"

    struct Tab: Equatable, Sendable {
        let url: String
        let title: String
    }

    /// The site a badge app stands for, from its name (the Gmail and Google Chat web apps).
    static func site(forBadgeName name: String) -> String? {
        let lowered = name.lowercased()
        if lowered.contains("gmail") { return gmailSite }
        if lowered.contains("google chat") { return chatSite }
        return nil
    }

    /// Site → unread count. Each Google account (`/u/N/`) counts once, several accounts add up.
    /// A tab without a number in its title is 0, except a Gmail tab not showing the inbox (its
    /// title counts another label), which says nothing.
    static func counts(from tabs: [Tab]) -> [String: Int] {
        var perAccount: [String: [String: Int]] = [:]
        for tab in tabs {
            guard let site = site(ofURL: tab.url) else { continue }
            let number = count(inTitle: tab.title)
            if number == nil, site == gmailSite, !showsInbox(tab.url) { continue }
            let account = account(ofURL: tab.url)
            perAccount[site, default: [:]][account] = max(perAccount[site]?[account] ?? 0, number ?? 0)
        }
        return perAccount.mapValues { $0.values.reduce(0, +) }
    }

    static func site(ofURL url: String) -> String? {
        let lowered = url.lowercased()
        if lowered.contains("chat.google.com") || lowered.contains("mail.google.com/chat") { return chatSite }
        if lowered.contains("mail.google.com/mail") { return gmailSite }
        return nil
    }

    /// The first "(N)" in a title.
    static func count(inTitle title: String) -> Int? {
        guard let match = title.firstMatch(of: /\((\d{1,6})\)/) else { return nil }
        return Int(match.1)
    }

    private static func account(ofURL url: String) -> String {
        url.firstMatch(of: /\/u\/(\d+)/).map { String($0.1) } ?? "0"
    }

    private static func showsInbox(_ url: String) -> Bool {
        guard let fragment = url.split(separator: "#", maxSplits: 1).dropFirst().first else { return true }
        return fragment.lowercased().hasPrefix("inbox")
    }

    private static let queue = DispatchQueue(label: "dynotch.browser-tab-badges")

    /// The Gmail and Google Chat tabs of the default browser; nil if it is not running, cannot
    /// be read, or refuses. Two Apple Events in all, however many tabs are open.
    static func read() async -> [Tab]? {
        guard let browser = browser(defaultBrowser: ActiveBrowser.defaultBundleID()),
              !NSRunningApplication.runningApplications(withBundleIdentifier: browser.id).isEmpty
        else { return nil }
        let source = script(browserID: browser.id, titleKey: browser.titleKey)
        return await AppleScriptRunner.run(source, on: queue, log: "badges", what: "\(browser.id) tabs") { result in
            parse(result.stringValue ?? "")
        }
    }

    static func parse(_ text: String) -> [Tab] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            return Tab(url: String(parts[0]), title: String(parts[1]))
        }
    }

    private static func script(browserID: String, titleKey: String) -> String {
        """
    tell application id "\(browserID)"
        set theURLs to URL of every tab of every window
        set theTitles to \(titleKey) of every tab of every window
    end tell
    set out to ""
    repeat with i from 1 to count of theURLs
        set windowURLs to item i of theURLs
        set windowTitles to item i of theTitles
        repeat with j from 1 to count of windowURLs
            set theURL to item j of windowURLs as text
            if theURL contains "mail.google.com" or theURL contains "chat.google.com" then
                set out to out & theURL & (character id 9) & (item j of windowTitles as text) & (character id 10)
            end if
        end repeat
    end repeat
    return out
    """
    }
}
