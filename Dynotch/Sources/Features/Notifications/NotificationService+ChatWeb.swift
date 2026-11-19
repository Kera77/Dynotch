import Foundation

// Google Chat read from its web app (spec GW-5…GW-8).
extension NotificationService {
    /// How long a Google Chat notification stays without its conversation ever looking unread
    /// (it may have been read in the web app right away).
    private nonisolated static let unreadGrace: TimeInterval = 90

    func startChatWeb() {
        chatWeb.onSnapshot = { [weak self] snapshot in
            self?.dropReadInChat(snapshot)
            self?.addUnreadFromChat(snapshot)
        }
        chatWeb.start()
    }

    func isGoogleChat(_ notification: AppNotification) -> Bool {
        ChatSources.isGoogleChat(notification, catalog: catalog)
    }

    /// New Google Chat notifications: look at the web app at once (spec GW-6).
    func chatWebNoticed(_ incoming: [AppNotification]) {
        if incoming.contains(where: isGoogleChat) { chatWeb.refresh() }
    }

    /// Clicking into a Google Chat card's reply field reads the conversation in the web app too (spec GW-8).
    func replyFieldFocused(_ notification: AppNotification) {
        guard isGoogleChat(notification) else { return }
        chatWeb.markRead(title: notification.title)
    }

    /// A Google Chat message whose conversation the web app no longer shows unread leaves the
    /// notch (spec GW-7). Unknown or ambiguous conversations stay.
    func dropReadInChat(_ snapshot: ChatWebSnapshot, now: Date = Date()) {
        let gone = Set(recent.filter { notification in
            guard isGoogleChat(notification),
                  let conversation = GoogleChatWebService.match(notification.title, in: snapshot.conversations)
            else { return false }
            return Self.isRead(
                conversation, notifiedAt: notification.date, lastSeenUnread: chatWeb.lastSeenUnread[conversation.id], now: now
            )
        }.map(\.id))
        guard !gone.isEmpty else { return }
        DiagnosticsLog.append("notification-records", "read in Google Chat: \(gone.sorted())")
        recent.removeAll { gone.contains($0.id) }
        unseen.removeAll { gone.contains($0.id) }
        focus?.notifications.removeAll { gone.contains($0.id) }
        if let peek, gone.contains(peek.id) { clearPeek() }
    }

    /// Marks the cards made from the web app's sidebar, not from a notification.
    nonisolated static let chatWebSource = "dynotch.google-chat-web"

    /// A conversation the web app shows unread, with no Google Chat notification in the list
    /// (Google sends none while the web app is open): a card with its name (spec GW-5b). Found
    /// at launch it is only listed; found later it pops up like a notification. A card closed
    /// with X comes back only when the conversation was read and gets unread again.
    func addUnreadFromChat(_ snapshot: ChatWebSnapshot, now: Date = Date()) {
        let primed = chatWebPrimed
        chatWebPrimed = true
        let unread = snapshot.conversations.filter(\.isUnread)
        chatUnreadCarded.formIntersection(unread.map(\.id))
        guard let identifier = GoogleChatWebService.webAppIdentifier(), isEnabled(catalog.app(for: identifier)) else { return }
        let listed = recent.filter(isGoogleChat)
        let cards = unread.filter { conversation in
            !chatUnreadCarded.contains(conversation.id) && !conversation.name.isEmpty
                && !listed.contains { GoogleChatWebService.match($0.title, in: [conversation]) != nil }
        }.map { conversation -> AppNotification in
            chatUnreadCarded.insert(conversation.id)
            internalID -= 1
            var card = AppNotification(
                id: internalID, appIdentifier: identifier, title: conversation.name, subtitle: "",
                body: "Unread in Google Chat", date: now, site: "chat.google.com"
            )
            card.sourceIdentifier = Self.chatWebSource
            return card
        }
        guard !cards.isEmpty else { return }
        DiagnosticsLog.append("notification-records", "unread in Google Chat without a notification: \(cards.count) card(s)")
        recent = Array((cards + recent).prefix(Self.historyLimit))
        guard primed else { return }
        unseen = Array((unseen + cards).suffix(Self.unseenLimit))
        if let newest = cards.last { showPeekAgain(newest) }
    }

    /// A real Google Chat notification replaces the card made for its conversation (spec GW-5b).
    func isReplacedChatCard(_ old: AppNotification, by incoming: [AppNotification]) -> Bool {
        guard old.sourceIdentifier == Self.chatWebSource else { return false }
        let conversation = ChatWebConversation(id: "", name: old.title, isUnread: true)
        return incoming.contains { isGoogleChat($0) && GoogleChatWebService.match($0.title, in: [conversation]) != nil }
    }

    /// Read: not unread now, and either seen unread since the message came, or long enough ago.
    nonisolated static func isRead(
        _ conversation: ChatWebConversation, notifiedAt date: Date, lastSeenUnread: Date?, now: Date
    ) -> Bool {
        guard !conversation.isUnread else { return false }
        if let lastSeenUnread, lastSeenUnread >= date { return true }
        return now.timeIntervalSince(date) > unreadGrace
    }
}
