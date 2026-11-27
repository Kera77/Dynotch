import AppKit
import ApplicationServices

/// A chat list row and its spoken label ("Unread message …"), carried down to its children.
struct TeamsWebRow {
    let element: AXUIElement
    let label: String
}

/// Reads the web Teams through Accessibility only, in the browser window where it is the active
/// tab: no cookies, no network, no script in the page (spec MT-1, MT-2). Elements are found again
/// for every step; nothing here is kept between calls.
enum TeamsWebReader {
    private static let elementLimit = 15_000
    private static let sendTitles: Set<String> = ["Send", "Küldés"]

    /// A Teams window: the browser's pid and the window.
    struct Page: @unchecked Sendable {
        let pid: pid_t
        let window: AXUIElement
        let browser: String
    }

    // MARK: - Finding the page

    /// The first browser window showing Teams.
    nonisolated static func findPage() -> Page? {
        for app in NSWorkspace.shared.runningApplications where isBrowser(app) {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            // Chromium shows its pages to Accessibility only when asked to (spec GW-3).
            AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            let windows = (AXRead.value(element, kAXWindowsAttribute) as? [AXUIElement]) ?? []
            for window in windows where TeamsPage.isTeamsWindow(title: AXRead.string(window, kAXTitleAttribute) ?? "") {
                return Page(pid: app.processIdentifier, window: window, browser: app.localizedName ?? "browser")
            }
        }
        return nil
    }

    nonisolated private static func isBrowser(_ app: NSRunningApplication) -> Bool {
        let id = (app.bundleIdentifier ?? "").lowercased()
        return WebNotificationSource.browserIdentifiers.contains(id) || id.hasPrefix("com.apple.safari.webapp")
            || (id.contains(".app.") && WebNotificationSource.browserIdentifiers.contains { id.hasPrefix($0 + ".app.") })
    }

    // MARK: - Reading

    /// The page's state, or nil when the window shows something other than Teams.
    nonisolated static func snapshot(_ page: Page) -> TeamsSnapshot? {
        var walker = Walker()
        walker.walk(page.window)
        guard walker.foundPage else { return nil }
        var snapshot = walker.snapshot
        snapshot.browser = page.browser
        return snapshot
    }

    /// Walks the page once, in page order, and collects what the reader needs.
    struct Walker {
        var foundPage = false
        var snapshot = TeamsSnapshot()
        var rows: [String: AXUIElement] = [:]
        var composer: AXUIElement?
        var sendButton: AXUIElement?
        var controls: [TeamsControl: AXUIElement] = [:]
        /// Stops once this chat's row is found.
        var stopAtChat: String?
        private var pageTitle = ""
        private var meeting = TeamsMeeting(title: "")
        private var mine: Set<String> = []
        private var authors: [String: String] = [:]
        private var lastAuthor: String?
        private var visited = 0

        /// Depth first without recursion; each element carries its chat list row, if any.
        mutating func walk(_ root: AXUIElement) {
            var stack: [(AXUIElement, TeamsWebRow?)] = [(root, nil)]
            while let (element, row) = stack.popLast() {
                visited += 1
                guard visited < TeamsWebReader.elementLimit else { break }
                if let stopAtChat, rows[stopAtChat] != nil { break }
                guard let childRow = visit(element, row: row) else { continue }
                stack += AXRead.children(element).reversed().map { ($0, childRow) }
            }
            finish()
        }

        /// Reads one element; the row its children belong to, or nil to skip them.
        private mutating func visit(_ element: AXUIElement, row: TeamsWebRow?) -> TeamsWebRow?? {
            let role = AXRead.string(element, kAXRoleAttribute) ?? ""
            if role == "AXWebArea" {
                readPage(element)
                return .some(row)
            }
            var row = row
            if role == "AXRow" || AXRead.string(element, kAXSubroleAttribute) == "AXOutlineRow" {
                row = TeamsWebRow(element: element, label: Self.label(of: element))
            }
            let domID = AXRead.string(element, "AXDOMIdentifier") ?? ""
            if !domID.isEmpty, let part = TeamsPage.part(ofDOM: domID) {
                return read(part, element: element, row: row)
            }
            if domID.hasPrefix(TeamsPage.composerPrefix) {
                composer = element
                return nil
            }
            if role == (kAXButtonRole as String) || role == (kAXCheckBoxRole as String) || role == (kAXPopUpButtonRole as String) {
                readButton(element, domID: domID)
                return nil
            }
            return .some(row)
        }

        private mutating func read(_ part: TeamsPage.Part, element: AXUIElement, row: TeamsWebRow?) -> TeamsWebRow?? {
            switch part {
            case .title(let id):
                let label = row?.label ?? ""
                var chat = TeamsChat(id: id, name: Self.text(of: element))
                chat.isUnread = TeamsPage.isUnread(label: label)
                chat.isMention = TeamsPage.isMention(label: label)
                if !snapshot.chats.contains(where: { $0.id == id }) { snapshot.chats.append(chat) }
                rows[id] = row?.element ?? element
            case .preview(let id):
                update(id) { $0.preview = Self.text(of: element) }
            case .time(let id):
                update(id) { $0.time = Self.text(of: element) }
            case .header(let id):
                if snapshot.openID == nil { snapshot.openID = id }
                return .some(row)
            case .author, .body, .content:
                return readMessage(part, element: element) ? .some(row) : nil
            }
            return nil
        }

        /// A message's author, body or text; whether its children are to be read.
        private mutating func readMessage(_ part: TeamsPage.Part, element: AXUIElement) -> Bool {
            switch part {
            case .author(let id):
                authors[id] = Self.text(of: element)
            case .body(let id):
                if AXRead.strings(element, "AXDOMClassList").contains(TeamsPage.ownMessageClass) { mine.insert(id) }
                return true
            case .content(let id):
                let isMine = mine.contains(id)
                if let author = authors[id] { lastAuthor = author }
                let text = Self.text(of: element)
                if !text.isEmpty, !snapshot.messages.contains(where: { $0.id == id }) {
                    snapshot.messages.append(TeamsMessage(id: id, sender: isMine ? nil : lastAuthor, text: text, isMine: isMine))
                }
            default: break
            }
            return false
        }

        private mutating func update(_ id: String, _ change: (inout TeamsChat) -> Void) {
            guard let index = snapshot.chats.firstIndex(where: { $0.id == id }) else { return }
            change(&snapshot.chats[index])
        }

        private mutating func readButton(_ button: AXUIElement, domID: String) {
            let label = Self.label(of: button)
            if composer != nil, sendButton == nil, TeamsWebReader.sendTitles.contains(label) {
                sendButton = button
                return
            }
            guard let control = TeamsPage.control(domID: domID, label: label), controls[control] == nil else { return }
            controls[control] = button
            let value = (AXRead.value(button, kAXValueAttribute) as? NSNumber)?.intValue
            switch control {
            case .mic: meeting.isMuted = TeamsPage.isMuted(label: label, toggleValue: value)
            case .camera: meeting.isCameraOn = TeamsPage.isCameraOn(label: label, toggleValue: value)
            case .hand: meeting.isHandRaised = TeamsPage.isHandRaised(label: label, toggleValue: value)
            case .share, .leave: break
            }
        }

        private mutating func readPage(_ area: AXUIElement) {
            guard TeamsPage.isTeamsHost(AXRead.url(area)?.host) else { return }
            foundPage = true
            pageTitle = AXRead.string(area, kAXTitleAttribute) ?? ""
        }

        /// A meeting is on while its toolbar has Leave (spec MT-6).
        private mutating func finish() {
            guard controls[.leave] != nil else { return }
            meeting.title = TeamsPage.meetingTitle(fromPageTitle: pageTitle)
            meeting.controls = Set(controls.keys)
            snapshot.meeting = meeting
        }

        nonisolated static func label(of element: AXUIElement) -> String {
            let description = AXRead.string(element, kAXDescriptionAttribute) ?? ""
            let title = AXRead.string(element, kAXTitleAttribute) ?? ""
            return (description.isEmpty ? title : description).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        nonisolated static func text(of element: AXUIElement) -> String {
            if let value = AXRead.string(element, kAXValueAttribute), !value.isEmpty { return value }
            return AXRead.texts(in: element).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Acting (spec MT-4, MT-6)

    /// Opens a chat in the background: its row in the chat list is pressed.
    nonisolated static func open(chat id: String, on page: Page) -> Bool {
        var walker = Walker()
        walker.stopAtChat = id
        walker.walk(page.window)
        guard let row = walker.rows[id] else { return false }
        return AXUIElementPerformAction(row, kAXPressAction as CFString) == .success
    }

    /// Writes into the open chat's message box and presses Send.
    nonisolated static func send(_ text: String, on page: Page) -> Bool {
        var walker = Walker()
        walker.walk(page.window)
        guard let composer = walker.composer else { return false }
        AXUIElementSetAttributeValue(composer, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        // Typing through the selection goes through the editor's own input; the value is the fallback.
        if AXUIElementSetAttributeValue(composer, kAXSelectedTextAttribute as CFString, text as CFString) != .success {
            guard AXUIElementSetAttributeValue(composer, kAXValueAttribute as CFString, text as CFString) == .success else { return false }
        }
        for attempt in 0..<10 {
            var again = Walker()
            again.walk(page.window)
            if let button = again.sendButton, AXRead.bool(button, kAXEnabledAttribute) != false {
                return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
            }
            if attempt < 9 { Thread.sleep(forTimeInterval: 0.08) }
        }
        return false
    }

    /// Presses a control of the meeting's toolbar.
    nonisolated static func press(_ control: TeamsControl, on page: Page) -> Bool {
        var walker = Walker()
        walker.walk(page.window)
        guard let button = walker.controls[control] else { return false }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }
}
