import AppKit

/// The web Teams' tabs in the default browser, through AppleScript like the Gmail badge's (spec
/// B-2c): found in a background tab, moved to a window of its own on request, brought forward
/// from its badge (spec MT-13, B-15). Only Teams tabs' addresses and titles are read; nothing is logged.
enum TeamsTabs {
    struct Tab: Equatable, Sendable {
        /// A number in Chrome and Safari, text in Ardia.
        let windowID: String
        let index: Int
        let isActive: Bool
        let url: String
        let title: String
    }

    private static let queue = DispatchQueue(label: "dynotch.teams-tabs")
    /// Opened when no Teams tab is found; it leads on to the personal or the work Teams.
    static let homeURL = "https://teams.cloud.microsoft"

    /// The default browser, if its tabs can be read.
    private static var browser: (id: String, isSafari: Bool)? {
        guard let found = BrowserTabBadges.browser(defaultBrowser: ActiveBrowser.defaultBundleID()),
              !NSRunningApplication.runningApplications(withBundleIdentifier: found.id).isEmpty
        else { return nil }
        return (found.id, found.titleKey == "name")
    }

    /// The Teams tabs; nil when the browser is not running or cannot be read.
    static func read() async -> [Tab]? {
        guard let browser else { return nil }
        return await AppleScriptRunner.run(readScript(browser.id, isSafari: browser.isSafari), on: queue,
                                           log: "teams", what: "browser tabs") { parse($0.stringValue ?? "") }
    }

    /// A new window of the same browser with this tab's address; the old tab closes (spec MT-13).
    static func moveToOwnWindow(_ tab: Tab) async -> Bool {
        guard let browser, let url = quoted(tab.url) else { return false }
        let open = browser.isSafari
            ? "make new document with properties {URL:\(url)}"
            : "set newWindow to make new window\n        set URL of active tab of newWindow to \(url)"
        let source = """
        tell application id "\(browser.id)"
            \(open)
            close tab \(tab.index) of \(window(tab))
        end tell
        return "ok"
        """
        return await AppleScriptRunner.run(source, on: queue, log: "teams", what: "move tab") { _ in true } ?? false
    }

    /// The Teams tab comes forward in its browser; without one the web Teams opens (spec B-15).
    static func bringForward() async {
        guard let browser, let tab = await read()?.first else {
            if let url = URL(string: homeURL) { await MainActor.run { _ = NSWorkspace.shared.open(url) } }
            return
        }
        let select = browser.isSafari
            ? "set current tab of \(window(tab)) to tab \(tab.index) of \(window(tab))"
            : "set active tab index of \(window(tab)) to \(tab.index)"
        let source = """
        tell application id "\(browser.id)"
            \(select)
            set index of \(window(tab)) to 1
            activate
        end tell
        return "ok"
        """
        _ = await AppleScriptRunner.run(source, on: queue, log: "teams", what: "bring tab forward") { _ in true }
    }

    /// The first "(N)" in a Teams tab's title: its unread count, if it shows one.
    static func unread(in tabs: [Tab]) -> Int? {
        tabs.compactMap { BrowserTabBadges.count(inTitle: $0.title) }.max()
    }

    static func parse(_ text: String) -> [Tab] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 4, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 5, let index = Int(parts[1]), !parts[0].isEmpty,
                  parts[0].allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }),
                  TeamsPage.isTeamsHost(URL(string: parts[3])?.host)
            else { return nil }
            return Tab(windowID: parts[0], index: index, isActive: parts[2] == "true", url: parts[3], title: parts[4])
        }
    }

    /// `window id 12` or `window id "w-…"`, as the browser names it.
    private static func window(_ tab: Tab) -> String {
        Int(tab.windowID) != nil ? "window id \(tab.windowID)" : "window id \"\(tab.windowID)\""
    }

    /// An AppleScript string literal; nil for an address that could break out of it.
    private static func quoted(_ url: String) -> String? {
        guard url.hasPrefix("https://"), !url.contains("\""), !url.contains("\\"), !url.contains("\n") else { return nil }
        return "\"\(url)\""
    }

    private static func readScript(_ id: String, isSafari: Bool) -> String {
        let active = isSafari ? "index of current tab of w" : "active tab index of w"
        return """
        set out to ""
        tell application id "\(id)"
            repeat with w in every window
                set wid to id of w
                set activeIndex to \(active)
                set theURLs to URL of every tab of w
                set theTitles to \(isSafari ? "name" : "title") of every tab of w
                repeat with j from 1 to count of theURLs
                    set theURL to item j of theURLs as text
                    if theURL contains "teams." then
                        set t to character id 9
                        set out to out & wid & t & j & t & (j = activeIndex) & t & theURL & t
                        set out to out & (item j of theTitles as text) & (character id 10)
                    end if
                end repeat
            end repeat
        end tell
        return out
        """
    }
}
