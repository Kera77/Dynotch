import AppKit
import ApplicationServices

/// One conversation in the Google Chat web app's sidebar (spec GW-4).
struct ChatWebConversation: Equatable, Sendable {
    /// "dm/…" or "space/…", as the web app names it.
    let id: String
    let name: String
    let isUnread: Bool
    /// The unread count the sidebar shows ("1 értesítés"), if any (spec GW-5b).
    var unreadCount: Int?
    /// The last message as the Home list shows it, when the list could be read (spec GW-21).
    var preview: ChatWebPreview?

    /// The id without its kind: the part the page's address shows.
    var key: String { id.split(separator: "/").last.map(String.init) ?? id }
}

/// One row of the web app's Home list: the conversation's last message (spec GW-21).
struct ChatWebPreview: Equatable, Sendable {
    let name: String
    /// "4 perc", "12:30", "Tegnap": as the list shows it.
    let time: String
    /// Who wrote it: nil in a direct message, where it is the conversation's name.
    let sender: String?
    let text: String
    var isMine = false
    var isUnread = false
    var count: Int?
}

/// A message of the conversation open in the web app.
struct ChatWebMessage: Equatable, Sendable {
    let id: String
    let text: String
    /// Written by the owner: the web app heads the group "Ön"/"You" (spec GW-20).
    var isMine = false
    /// Who wrote it, from the group's sender heading; nil for the owner's own (spec GW-32).
    var sender: String?
}

/// What the Google Chat web app shows: its sidebar and the open conversation (spec GW-4).
struct ChatWebSnapshot: Equatable, Sendable {
    var conversations: [ChatWebConversation] = []
    /// The open conversation's key, from the page's address.
    var openID: String?
    var messages: [ChatWebMessage] = []
    /// The message box's text, nil when there is none.
    var composer: String?
    /// The Home list could be read: previews come with the conversations (spec GW-21, GW-24).
    var hasHome = false

    /// Unread messages in all: an unread conversation without a count counts one (spec GW-22).
    var unreadTotal: Int {
        conversations.filter(\.isUnread).reduce(0) { $0 + max($1.unreadCount ?? 1, 1) }
    }
}

/// Reads the Google Chat web app (Safari, added to the Dock) through Accessibility only: no
/// cookies, no network, no script in the page (spec GW-2). Its window may be on another Space.
/// Elements are found again for every step; nothing here is kept between calls.
enum GoogleChatWebReader {
    /// Sidebar items, messages and the send button as the web app marks them.
    private static let unreadClass = "H7du2"
    private static let messageSuffix = "/qJTHM"
    private static let sendTitles: Set<String> = ["Üzenet küldése", "Send message"]
    /// The sidebar's Home item (spec GW-30).
    private static let homeTitles: Set<String> = ["Kezdőlap", "Home"]
    /// A message group's sender heading, and the mark of the owner's own (spec GW-20).
    private static let senderHeadingClass = "ZTmjQb"
    private static let ownHeadingClass = "cPjwNc"
    private static let ownNames: Set<String> = ["Ön", "You", "Te"]
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

    /// A sender heading that names the owner: "Ön"/"You", or the web app's own mark.
    nonisolated static func isOwnHeading(name: String, classes: [String]) -> Bool {
        classes.contains(ownHeadingClass) || ownNames.contains(name)
    }

    /// Texts the sidebar puts beside a name: the unread marker.
    private static let unreadMarkers: Set<String> = ["olvasatlan", "unread"]

    /// The pin a pinned conversation's row carries ("Kitűzött beszélgetés", "Pinned"): not its
    /// name (spec GW-27).
    nonisolated static func isPinMarker(_ text: String) -> Bool {
        let folded = text.lowercased()
        return ["kitűzött beszélgetés", "kitűzve", "kitűzött", "pinned conversation", "pinned"].contains(folded)
            || folded.hasPrefix("kitűzött beszélgetés") || folded.hasPrefix("pinned conversation")
    }

    /// The conversation's name and unread count from a sidebar item's texts. Unread items start
    /// with "Olvasatlan"; direct messages start with the person's status ("Nincs a gépnél"), so
    /// their name is the last text; a space's name is the first one, its kind and topic follow.
    /// The count is the text starting with a number ("1 értesítés").
    nonisolated static func nameAndCount(_ texts: [String], isDirect: Bool) -> (name: String, count: Int?) {
        let trimmed = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isPinMarker($0) }
        let count = trimmed.lazy.compactMap { text -> Int? in
            let digits = text.prefix { $0.isNumber }
            guard !digits.isEmpty, text.dropFirst(digits.count).first == " " else { return nil }
            return Int(digits)
        }.first
        let rest = trimmed.filter { text in
            !unreadMarkers.contains(text.lowercased()) && !(text.first?.isNumber == true && text.contains(" "))
        }
        return ((isDirect ? rest.last : rest.first) ?? "", count)
    }

    /// A Home list row (spec GW-21).
    private static let homeItemClass = "o7n3Nd"
    private static let keyboardHints = ["Tab billentyű", "Tab key", "press Tab", "Press Tab"]

    /// Whether a text is the Home list's time: "4 perc", "2 óra", "12:30", "Tegnap", "H", "nov. 20.".
    nonisolated static func isTime(_ text: String) -> Bool {
        let patterns = [
            #"^\d+ (perc|óra|nap|min|mins|hr|hrs|hour|hours|day|days)$"#, #"^\d{1,2}:\d{2}( ?[AaPp][Mm])?$"#,
            #"^(Most|Tegnap|Now|Just now|Yesterday)$"#, #"^(H|K|Sze|Cs|P|Szo|V|Mon|Tue|Wed|Thu|Fri|Sat|Sun)$"#,
            #"^[a-zé]{3,5}\. \d{1,2}\.$"#, #"^\d{4}\. "#, #"^[A-Z][a-z]{2} \d{1,2}(, \d{4})?$"#
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    /// A Home list row from its texts in page order: name, time, "Olvasatlan", "Sender: text",
    /// keyboard hint, "1 értesítés". Only "Olvasatlan" makes it unread: an old space keeps its
    /// "1 értesítés" after it was read (spec GW-26). A direct message's status ("Nincs a gépnél") may come before
    /// its name. Nil when no time or no message is found.
    nonisolated static func homePreview(_ texts: [String]) -> ChatWebPreview? {
        let trimmed = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { text in !text.isEmpty && !isPinMarker(text) && !keyboardHints.contains { text.contains($0) } }
        guard let timeIndex = trimmed.firstIndex(where: isTime), timeIndex > 0 else { return nil }
        let name = trimmed[timeIndex - 1]
        var isUnread = false
        var count: Int?
        var message: String?
        for text in trimmed[(timeIndex + 1)...] {
            if unreadMarkers.contains(text.lowercased()) {
                isUnread = true
            } else if let number = leadingCount(text) {
                count = number
            } else if message == nil {
                message = text
            }
        }
        guard let message else { return nil }
        let (sender, body) = splitSender(message)
        return ChatWebPreview(
            name: name, time: trimmed[timeIndex], sender: sender, text: body,
            isMine: sender.map { ownNames.contains($0) } ?? false, isUnread: isUnread, count: isUnread ? count : nil
        )
    }

    /// "Gergő Karádi: Mindkettő jó" → ("Gergő Karádi", "Mindkettő jó"); a text without a short
    /// name before its first colon has no sender.
    nonisolated static func splitSender(_ message: String) -> (String?, String) {
        guard let colon = message.range(of: ": ") else { return (nil, message) }
        let sender = String(message[..<colon.lowerBound])
        guard !sender.isEmpty, sender.count <= 60, !sender.contains("\n"), !sender.contains("http") else { return (nil, message) }
        return (sender, String(message[colon.upperBound...]))
    }

    /// "1 értesítés" → 1: a number, a space and a word.
    private nonisolated static func leadingCount(_ text: String) -> Int? {
        let digits = text.prefix { $0.isNumber }
        guard !digits.isEmpty, text.dropFirst(digits.count).first == " ",
              text.split(separator: " ").count == 2 else { return nil }
        return Int(digits)
    }

    /// Previews joined to the sidebar's conversations: by the row's id, or else by an exact name.
    /// Unread in either list is unread (spec GW-21, GW-22).
    nonisolated static func merge(
        _ previews: [(id: String?, preview: ChatWebPreview)], into conversations: [ChatWebConversation]
    ) -> [ChatWebConversation] {
        var result = conversations
        for (id, preview) in previews {
            let index = id.flatMap { id in result.firstIndex { $0.id == id } }
                ?? (result.filter { $0.name == preview.name }.count == 1 ? result.firstIndex { $0.name == preview.name } : nil)
            guard let index else { continue }
            result[index].preview = preview
            if preview.isUnread && !result[index].isUnread {
                result[index] = ChatWebConversation(
                    id: result[index].id, name: result[index].name, isUnread: true,
                    unreadCount: preview.count, preview: preview
                )
            } else if let count = preview.count, count > (result[index].unreadCount ?? 0), result[index].isUnread {
                result[index].unreadCount = count
            }
        }
        return result
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
        snapshot.conversations = merge(walker.previews, into: walker.conversations)
        snapshot.hasHome = !walker.previews.isEmpty
        snapshot.openID = walker.openID
        snapshot.messages = walker.messages
        snapshot.composer = walker.composer.flatMap { AXRead.string($0, kAXValueAttribute) ?? "" }
        return (snapshot, token)
    }

    /// Walks the page once and collects what the reader needs.
    struct Walker {
        var conversations: [ChatWebConversation] = []
        var previews: [(id: String?, preview: ChatWebPreview)] = []
        var links: [String: AXUIElement] = [:]
        var messages: [ChatWebMessage] = []
        var openID: String?
        var foundPage = false
        var composer: AXUIElement?
        var sendButton: AXUIElement?
        var homeLink: AXUIElement?
        /// Stops the walk once this conversation's link is found.
        var stopAtLink: String?
        /// Stops the walk once the Home item is found.
        var stopAtHome = false
        /// Whether the last sender heading was the owner's: the messages under it are theirs.
        private var ownGroup = false
        /// The last sender heading's name: who wrote the messages under it (spec GW-32).
        private var groupSender: String?
        private var visited = 0

        /// Depth first, in page order, without recursion: the page is deeper than a background
        /// thread's stack allows (a crash in 0.69.0).
        mutating func walk(_ root: AXUIElement) {
            var stack = [root]
            while let element = stack.popLast() {
                visited += 1
                guard visited < GoogleChatWebReader.elementLimit else { return }
                if let stopAtLink, links[stopAtLink] != nil { return }
                if stopAtHome, homeLink != nil { return }
                if visit(element) { stack += AXRead.children(element).reversed() }
            }
        }

        /// Reads one element; whether its children are to be read.
        private mutating func visit(_ element: AXUIElement) -> Bool {
            let role = AXRead.string(element, kAXRoleAttribute) ?? ""
            if role == "AXWebArea" { readPage(element) }
            let domID = AXRead.string(element, "AXDOMIdentifier") ?? ""
            if stopAtHome, homeLink == nil, isHomeItem(element, role: role) {
                homeLink = element
                return false
            }
            if role == (kAXGroupRole as String),
               AXRead.strings(element, "AXDOMClassList").contains(GoogleChatWebReader.homeItemClass) {
                if let preview = GoogleChatWebReader.homePreview(AXRead.texts(in: element)) {
                    previews.append((GoogleChatWebReader.conversationID(fromDOM: domID), preview))
                }
                return false
            }
            if let id = GoogleChatWebReader.conversationID(fromDOM: domID) {
                readItem(element, id: id)
                return false
            }
            if domID.hasSuffix(GoogleChatWebReader.messageSuffix) {
                let text = AXRead.texts(in: element).joined(separator: " ")
                let id = String(domID.dropLast(GoogleChatWebReader.messageSuffix.count))
                messages.append(ChatWebMessage(id: id, text: text, isMine: ownGroup, sender: ownGroup ? nil : groupSender))
                return false
            }
            if role == "AXHeading" { readHeading(element) }
            if role == (kAXTextAreaRole as String), composer == nil { composer = element }
            if role == (kAXButtonRole as String), composer != nil, sendButton == nil, isSendButton(element) {
                sendButton = element
            }
            return true
        }

        /// A sender heading starts a group of messages: the owner's own or someone else's.
        private mutating func readHeading(_ heading: AXUIElement) {
            let classes = AXRead.strings(heading, "AXDOMClassList")
            guard classes.contains(GoogleChatWebReader.senderHeadingClass) else { return }
            let name = (AXRead.string(heading, kAXTitleAttribute) ?? AXRead.texts(in: heading).first ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            ownGroup = GoogleChatWebReader.isOwnHeading(name: name, classes: classes)
            groupSender = name.isEmpty ? nil : name
        }

        /// The sidebar's Home: a link to …/app/home, or a link or button titled Home.
        private func isHomeItem(_ element: AXUIElement, role: String) -> Bool {
            guard role == "AXLink" || role == (kAXButtonRole as String) else { return false }
            if let url = AXRead.url(element), url.path.hasSuffix("/app/home") || url.fragment?.hasSuffix("/home") == true { return true }
            let title = AXRead.string(element, kAXTitleAttribute) ?? AXRead.string(element, kAXDescriptionAttribute) ?? ""
            return GoogleChatWebReader.homeTitles.contains(title.trimmingCharacters(in: .whitespacesAndNewlines))
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
            let texts = AXRead.children(link).filter { AXRead.string($0, kAXRoleAttribute) == (kAXStaticTextRole as String) }
                .compactMap { AXRead.string($0, kAXValueAttribute) }
            let (name, count) = GoogleChatWebReader.nameAndCount(texts, isDirect: id.hasPrefix("dm/"))
            let unread = GoogleChatWebReader.isUnread(label: label, classes: classes)
            let conversation = ChatWebConversation(id: id, name: name, isUnread: unread, unreadCount: unread ? count : nil)
            if let index = conversations.firstIndex(where: { $0.id == id }) {
                if unread, !conversations[index].isUnread { conversations[index] = conversation }
                return
            }
            conversations.append(conversation)
            links[id] = link
        }
    }
}
