import AppKit

/// Unread counts from the titles of the Gmail and Google Chat tabs open in Ardia (spec B-2b):
/// "Inbox (9) - …" → 9. Only those tabs' addresses and titles are read, nothing is logged but
/// the counts.
enum BrowserTabBadges {
    static let browserID = "com.ardia.browser"
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

    /// The Gmail and Google Chat tabs of Ardia; nil if Ardia is not running or refuses.
    /// Two Apple Events in all, however many tabs are open.
    static func read() async -> [Tab]? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: browserID).isEmpty else { return nil }
        return await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
                if let error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                    DiagnosticsLog.append("badges", "Ardia tabs could not be read (\(code))")
                }
                continuation.resume(returning: result.map { parse($0.stringValue ?? "") })
            }
        }
    }

    static func parse(_ text: String) -> [Tab] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            return Tab(url: String(parts[0]), title: String(parts[1]))
        }
    }

    private static let script = """
    tell application id "\(browserID)"
        set theURLs to URL of every tab of every window
        set theTitles to title of every tab of every window
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
