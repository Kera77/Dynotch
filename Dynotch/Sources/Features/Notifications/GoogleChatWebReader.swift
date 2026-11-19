import AppKit
import ApplicationServices

/// One conversation in the Google Chat web app's sidebar (spec GW-4).
struct ChatWebConversation: Equatable, Sendable {
    /// "dm/…" or "space/…", as the web app names it.
    let id: String
    let name: String
    let isUnread: Bool

    /// The id without its kind: the part the page's address shows.
    var key: String { id.split(separator: "/").last.map(String.init) ?? id }
}

/// A message of the conversation open in the web app.
struct ChatWebMessage: Equatable, Sendable {
    let id: String
    let text: String
}

/// What the Google Chat web app shows: its sidebar and the open conversation (spec GW-4).
struct ChatWebSnapshot: Equatable, Sendable {
    var conversations: [ChatWebConversation] = []
    /// The open conversation's key, from the page's address.
    var openID: String?
    var messages: [ChatWebMessage] = []
    /// The message box's text, nil when there is none.
    var composer: String?
}

/// Reads the Google Chat web app (Safari, added to the Dock) through Accessibility only: no
/// cookies, no network, no script in the page (spec GW-2). Its window may be on another Space.
/// Elements are found again for every step; nothing here is kept between calls.
enum GoogleChatWebReader {
    /// Sidebar items, messages and the send button as the web app marks them.
    private static let unreadClass = "H7du2"
    private static let messageSuffix = "/qJTHM"
    private static let sendTitles: Set<String> = ["Üzenet küldése", "Send message"]
    private static let elementLimit = 8000

    // MARK: - Pure helpers (tested)

    /// "space/AAAA/SCcFR" → "space/AAAA"; nil for anything else.
    nonisolated static func conversationID(fromDOM identifier: String) -> String? {
        let parts = identifier.split(separator: "/")
        guard parts.count >= 2, parts[0] == "space" || parts[0] == "dm" else { return nil }
        return "\(parts[0])/\(parts[1])"
    }

    /// "/app/chat/AAAA" → "AAAA", also for direct messages ("/app/dm/xyz" → "xyz"); threads
    /// after it are ignored. Compared with `ChatWebConversation.key`.
    nonisolated static func openID(fromPath path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        guard let app = parts.firstIndex(of: "app"), parts.count > app + 2,
              ["chat", "dm", "space"].contains(parts[app + 1])
        else { return nil }
        return parts[app + 2]
    }

    /// Unread items are bold, and their label offers the last message's preview (⌥0).
    nonisolated static func isUnread(label: String, classes: [String]) -> Bool {
        classes.contains(unreadClass) || label.contains("Option + 0") || label.contains("Option+0")
    }

    /// The message box counts as empty with only spaces, new lines or zero-width characters.
    nonisolated static func isBlank(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) || $0.value == 0x200B || $0.value == 0xFEFF }
    }

    // MARK: - Reading

    /// The web app's state, or nil when its page cannot be found or recognized.
    /// - Parameter windowToken: a remote window token found earlier, tried first.
    nonisolated static func snapshot(pid: pid_t, windowToken: UInt64?) -> (ChatWebSnapshot, UInt64?)? {
        let (windows, token) = AXWindows.all(pid: pid, hint: windowToken)
        var walker = Walker()
        for window in windows { walker.walk(window) }
        guard walker.foundPage, !walker.conversations.isEmpty else { return nil }
        var snapshot = ChatWebSnapshot()
        snapshot.conversations = walker.conversations
        snapshot.openID = walker.openID
        snapshot.messages = walker.messages
        snapshot.composer = walker.composer.flatMap { AXRead.string($0, kAXValueAttribute) ?? "" }
        return (snapshot, token)
    }

    // MARK: - Acting

    /// Opens a conversation in the web app, in the background (spec GW-8).
    nonisolated static func open(_ conversationID: String, pid: pid_t, windowToken: UInt64?) -> Bool {
        var walker = Walker()
        for window in AXWindows.all(pid: pid, hint: windowToken).0 { walker.walk(window) }
        guard let link = walker.links[conversationID] else { return false }
        return AXUIElementPerformAction(link, kAXPressAction as CFString) == .success
    }

    /// Writes into the open conversation's message box; true when it then holds the text.
    nonisolated static func write(_ text: String, pid: pid_t, windowToken: UInt64?) -> Bool {
        var walker = Walker()
        for window in AXWindows.all(pid: pid, hint: windowToken).0 { walker.walk(window) }
        guard let composer = walker.composer else { return false }
        AXUIElementSetAttributeValue(composer, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        guard AXUIElementSetAttributeValue(composer, kAXValueAttribute as CFString, text as CFString) == .success else { return false }
        let written = AXRead.string(composer, kAXValueAttribute) ?? ""
        return written.trimmingCharacters(in: .whitespacesAndNewlines) == text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Presses the send button, only when it is enabled (it is once the web app took the text).
    nonisolated static func pressSend(pid: pid_t, windowToken: UInt64?) -> Bool {
        var walker = Walker()
        for window in AXWindows.all(pid: pid, hint: windowToken).0 { walker.walk(window) }
        guard let button = walker.sendButton, AXRead.bool(button, kAXEnabledAttribute) != false else { return false }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    /// Walks the page once and collects what the reader needs.
    private struct Walker {
        var conversations: [ChatWebConversation] = []
        var links: [String: AXUIElement] = [:]
        var messages: [ChatWebMessage] = []
        var openID: String?
        var foundPage = false
        var composer: AXUIElement?
        var sendButton: AXUIElement?
        private var visited = 0

        mutating func walk(_ element: AXUIElement) {
            visited += 1
            guard visited < GoogleChatWebReader.elementLimit else { return }
            let role = AXRead.string(element, kAXRoleAttribute) ?? ""
            if role == "AXWebArea" { readPage(element) }
            let domID = AXRead.string(element, "AXDOMIdentifier") ?? ""
            if let id = GoogleChatWebReader.conversationID(fromDOM: domID) {
                readItem(element, id: id)
                return
            }
            if domID.hasSuffix(GoogleChatWebReader.messageSuffix) {
                let text = AXRead.texts(in: element).joined(separator: " ")
                messages.append(ChatWebMessage(id: String(domID.dropLast(GoogleChatWebReader.messageSuffix.count)), text: text))
                return
            }
            if role == (kAXTextAreaRole as String), composer == nil { composer = element }
            if role == (kAXButtonRole as String), composer != nil, sendButton == nil, isSendButton(element) {
                sendButton = element
            }
            for child in AXRead.children(element) { walk(child) }
        }

        private func isSendButton(_ button: AXUIElement) -> Bool {
            let title = AXRead.string(button, kAXTitleAttribute) ?? AXRead.string(button, kAXDescriptionAttribute) ?? ""
            return GoogleChatWebReader.sendTitles.contains(title)
        }

        private mutating func readPage(_ area: AXUIElement) {
            guard let url = AXRead.url(area), url.host == "chat.google.com" || url.host == "mail.google.com" else { return }
            foundPage = true
            if openID == nil { openID = GoogleChatWebReader.openID(fromPath: url.path) }
        }

        private mutating func readItem(_ item: AXUIElement, id: String) {
            guard let link = AXRead.children(item).first else { return }
            let label = AXRead.string(link, kAXTitleAttribute) ?? ""
            let classes = AXRead.strings(item, "AXDOMClassList")
            let name = AXRead.children(link).first { AXRead.string($0, kAXRoleAttribute) == (kAXStaticTextRole as String) }
                .flatMap { AXRead.string($0, kAXValueAttribute) } ?? ""
            let unread = GoogleChatWebReader.isUnread(label: label, classes: classes)
            if let index = conversations.firstIndex(where: { $0.id == id }) {
                if unread, !conversations[index].isUnread { conversations[index] = ChatWebConversation(id: id, name: name, isUnread: true) }
                return
            }
            conversations.append(ChatWebConversation(id: id, name: name, isUnread: unread))
            links[id] = link
        }
    }
}

/// Small Accessibility accessors.
enum AXRead {
    nonisolated static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    nonisolated static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    nonisolated static func strings(_ element: AXUIElement, _ attribute: String) -> [String] {
        value(element, attribute) as? [String] ?? []
    }

    nonisolated static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        value(element, attribute) as? Bool
    }

    nonisolated static func url(_ element: AXUIElement) -> URL? {
        value(element, kAXURLAttribute) as? URL
    }

    nonisolated static func children(_ element: AXUIElement) -> [AXUIElement] {
        guard let list = value(element, kAXChildrenAttribute), CFGetTypeID(list) == CFArrayGetTypeID() else { return [] }
        return (list as? [AXUIElement]) ?? []
    }

    /// The static texts under an element, in order.
    nonisolated static func texts(in element: AXUIElement, depth: Int = 0) -> [String] {
        guard depth < 12 else { return [] }
        if string(element, kAXRoleAttribute) == (kAXStaticTextRole as String) {
            return [string(element, kAXValueAttribute) ?? ""].filter { !$0.isEmpty }
        }
        return children(element).flatMap { texts(in: $0, depth: depth + 1) }
    }
}
