import Foundation

// Google Chat read from its web app (spec GW-5…GW-8).
extension NotificationService {
    /// How long a Google Chat notification stays without its conversation ever looking unread
    /// (it may have been read in the web app right away).
    private nonisolated static let unreadGrace: TimeInterval = 90

    func startChatWeb() {
        chatWeb.onSnapshot = { [weak self] snapshot in
            self?.fillOpenedCards(snapshot)
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
            guard isGoogleChat(notification), (chatWebHeld[notification.id] ?? .distantPast) < now,
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
                body: Self.unreadText(conversation.unreadCount), date: now, site: "chat.google.com"
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

    nonisolated static func unreadText(_ count: Int?) -> String {
        guard let count, count > 1 else { return "1 unread message in Google Chat" }
        return "\(count) unread messages in Google Chat"
    }

    /// Opening a card made without a notification opens its conversation in the web app in the
    /// background (read there too, GW-8), so its messages can be shown (spec GW-5c, GW-17).
    func cardOpened(_ stack: [AppNotification]) {
        for card in stack where card.sourceIdentifier == Self.chatWebSource {
            guard chatWebOpened[card.id] == nil,
                  let conversation = chatWeb.conversation(forTitle: card.title), conversation.isUnread
            else { continue }
            chatWebOpened[card.id] = conversation.id
            chatWebHeld[card.id] = .distantFuture
            if chatWebTexts[card.id] == nil {
                chatWebPending[conversation.id] = card.id
                giveUpLoading(conversation.id, card: card.id)
            }
            chatWeb.markRead(title: card.title)
        }
    }

    /// The messages did not come in time: the card shows its count again (spec GW-19).
    private func giveUpLoading(_ conversationID: String, card: Int64) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, self.chatWebPending[conversationID] == card else { return }
            self.chatWebPending[conversationID] = nil
            DiagnosticsLog.append("google-chat-web", "card messages not read in time")
            self.objectWillChange.send()
        }
    }

    /// Closed without a reply: the conversation goes back to unread in the web app, and its card
    /// stays (spec GW-17).
    func cardsClosed(_ cards: [AppNotification]) {
        for card in cards {
            guard let conversationID = chatWebOpened.removeValue(forKey: card.id) else { continue }
            chatWebPending[conversationID] = nil
            chatWebHeld[card.id] = Date().addingTimeInterval(Self.unreadAgainGrace)
            chatWeb.markUnread(conversationID: conversationID)
        }
    }

    /// Every open card is closed with the notch.
    func allCardsClosed() {
        cardsClosed(recent.filter { chatWebOpened[$0.id] != nil })
    }

    /// Answered: it stays read, and the card goes as any read one (spec GW-17, GW-7).
    func chatCardAnswered(_ notification: AppNotification) {
        for card in recent where chatWebOpened[card.id] != nil
            && GoogleChatJump.conversationName(from: card.title) == GoogleChatJump.conversationName(from: notification.title) {
            chatWebOpened[card.id] = nil
            chatWebHeld[card.id] = nil
        }
    }

    /// Time for "Mark as unread" to show in the web app before a read look drops the card.
    private nonisolated static let unreadAgainGrace: TimeInterval = 15

    /// Whether the card is still loading its messages from the web app (spec GW-17).
    func isLoadingChatTexts(_ notification: AppNotification) -> Bool {
        chatWebPending.values.contains(notification.id)
    }

    /// "Open in Google Chat": the web app in front with the conversation, or the app (spec GW-19).
    func openInGoogleChat(_ notification: AppNotification) {
        if !chatWeb.openInApp(title: notification.title) { catalog.open(notification.appIdentifier) }
    }

    /// The opened conversation's last messages go into its card: as many as were unread (1…8).
    func fillOpenedCards(_ snapshot: ChatWebSnapshot) {
        guard !chatWebPending.isEmpty, let openID = snapshot.openID, !snapshot.messages.isEmpty else { return }
        for (conversationID, cardID) in chatWebPending where conversationID.split(separator: "/").last.map(String.init) == openID {
            chatWebPending[conversationID] = nil
            let count = min(max(snapshot.conversations.first { $0.id == conversationID }?.unreadCount ?? 0, 1), 8)
            let card = recent.first { $0.id == cardID }
            let wanted = max(count, Self.unreadCount(in: card?.body) ?? 1)
            let texts = snapshot.messages.suffix(wanted).map(\.text).filter { !$0.isEmpty }
            guard !texts.isEmpty else { continue }
            chatWebTexts[cardID] = Array(texts)
            DiagnosticsLog.append("notification-records", "Google Chat card filled from the web app: \(texts.count) message(s)")
        }
    }

    /// The count in a card's "N unread messages…" text.
    nonisolated static func unreadCount(in body: String?) -> Int? {
        body.flatMap { Int($0.prefix { $0.isNumber }) }
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
