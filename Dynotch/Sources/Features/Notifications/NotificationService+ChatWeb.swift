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
            self?.refreshChatCards(snapshot)
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
    /// From then on the card stays until it is closed (spec E-32).
    func replyFieldFocused(_ notification: AppNotification) {
        answering = notification
        guard isGoogleChat(notification) else { return }
        chatWeb.markRead(title: notification.title)
    }

    /// A Google Chat message whose conversation the web app no longer shows unread leaves the
    /// notch (spec GW-7). Unknown or ambiguous conversations stay.
    func dropReadInChat(_ snapshot: ChatWebSnapshot, now: Date = Date()) {
        let gone = Set(recent.filter { notification in
            guard isGoogleChat(notification), (chatWebHeld[notification.id] ?? .distantPast) < now, !isAnswering(notification),
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
        guard let identifier = GoogleChatWebService.webAppIdentifier(), isEnabled(catalog.app(for: identifier)) else {
            if !unread.isEmpty { logChatSkipped("Google Chat unread without a card: \(unread.count) (web app off in Notifications)") }
            return
        }
        // Only a notification that belongs to this conversation alone covers it (spec GW-25).
        let covered = Set(recent.filter(isGoogleChat).compactMap {
            GoogleChatWebService.match($0.title, in: snapshot.conversations)?.id
        })
        let waiting = unread.filter { !chatUnreadCarded.contains($0.id) }
        let cards = waiting.filter { !$0.name.isEmpty && !covered.contains($0.id) }.map { conversation -> AppNotification in
            chatUnreadCarded.insert(conversation.id)
            internalID -= 1
            var card = AppNotification(
                id: internalID, appIdentifier: identifier, title: conversation.name, subtitle: "",
                body: Self.cardText(conversation), date: now, site: "chat.google.com"
            )
            card.sourceIdentifier = Self.chatWebSource
            return card
        }
        logSkipped(waiting: waiting, carded: cards.count, covered: covered)
        guard !cards.isEmpty else { return }
        DiagnosticsLog.append("notification-records", "unread in Google Chat without a notification: \(cards.count) card(s)")
        recent = Array((cards + recent).prefix(Self.historyLimit))
        guard primed else { return }
        unseen = Array((unseen + cards).suffix(Self.unseenLimit))
        if let newest = cards.last { showPeekAgain(newest) }
    }

    /// Why an unread conversation got no card, without names (spec GW-25).
    private func logSkipped(waiting: [ChatWebConversation], carded: Int, covered: Set<String>) {
        guard waiting.count > carded else { return logChatSkipped("") }
        let noName = waiting.filter(\.name.isEmpty).count
        let byNotification = waiting.filter { !$0.name.isEmpty && covered.contains($0.id) }.count
        let skipped = waiting.count - carded
        logChatSkipped("Google Chat unread without a new card: \(skipped) (no name \(noName), has a notification \(byNotification))")
    }

    private func logChatSkipped(_ line: String) {
        guard line != chatSkippedLogged else { return }
        chatSkippedLogged = line
        if !line.isEmpty { DiagnosticsLog.append("notification-records", line) }
    }

    /// A card's text: the Home list's last message with its sender ("Gergő: Mindkettő jó",
    /// "You: …"), or the unread count when the list could not be read (spec GW-21, GW-23).
    nonisolated static func cardText(_ conversation: ChatWebConversation) -> String {
        guard let preview = conversation.preview, !preview.text.isEmpty else { return unreadText(conversation.unreadCount) }
        if preview.isMine { return "You: \(preview.text)" }
        guard let sender = preview.sender, sender != conversation.name else { return preview.text }
        return "\(sender): \(preview.text)"
    }

    /// A card made from the web app follows its conversation's last message (spec GW-23).
    func refreshChatCards(_ snapshot: ChatWebSnapshot) {
        var changed = false
        for (index, card) in recent.enumerated() where card.sourceIdentifier == Self.chatWebSource {
            guard let conversation = GoogleChatWebService.match(card.title, in: snapshot.conversations),
                  conversation.isUnread, conversation.preview != nil
            else { continue }
            let text = Self.cardText(conversation)
            guard text != card.body else { continue }
            var updated = AppNotification(
                id: card.id, appIdentifier: card.appIdentifier, title: card.title, subtitle: "",
                body: text, date: card.date, site: card.site
            )
            updated.sourceIdentifier = Self.chatWebSource
            recent[index] = updated
            changed = true
        }
        if changed { DiagnosticsLog.append("notification-records", "Google Chat cards updated from the Home list") }
    }

    /// The Google Chat badge counts the web app's unread messages while it can be read (spec GW-22).
    func chatBadgeLabel(for app: BadgeApp) -> String? {
        guard Self.isGoogleChatApp(app), chatWeb.state == .reading, let snapshot = chatWeb.snapshot else { return nil }
        let total = snapshot.unreadTotal
        return total > 0 ? String(total) : ""
    }

    /// The Google Chat badge's hover list: the unread conversations with their last message (spec GW-22).
    func chatBadgeRows(for app: BadgeApp, now: Date = Date()) -> [BadgeNotificationRow]? {
        guard Self.isGoogleChatApp(app), chatWeb.state == .reading, let snapshot = chatWeb.snapshot else { return nil }
        return snapshot.conversations.filter(\.isUnread).enumerated().map { index, conversation in
            BadgeNotificationRow(
                id: -20_000 - Int64(index), sender: conversation.name, detail: Self.cardText(conversation),
                date: conversation.preview.flatMap { ChatWebTime.date(from: $0.time, now: now) }
                    ?? chatWeb.lastSeenUnread[conversation.id] ?? now
            )
        }.sorted { $0.date > $1.date }
    }

    /// The Google Chat badge: the web app's, by name (not a highlighted Beeper network).
    nonisolated static func isGoogleChatApp(_ app: BadgeApp) -> Bool {
        BeeperNetworkBadge.network(fromBadgeID: app.bundleID) == nil
            && BrowserTabBadges.site(forBadgeName: app.name) == BrowserTabBadges.chatSite
    }

    nonisolated static func unreadText(_ count: Int?) -> String {
        guard let count, count > 1 else { return "1 unread message in Google Chat" }
        return "\(count) unread messages in Google Chat"
    }

    /// Opening a Google Chat card opens its conversation in the web app in the background (read
    /// there too, GW-8). A card made without a notification also gets the messages, as it has
    /// no text of its own (spec GW-5c, GW-17, GW-17b). One conversation is opened once.
    func cardOpened(_ stack: [AppNotification]) {
        var opened = Set<String>()
        for card in stack.reversed() where card.sourceIdentifier == Self.chatWebSource || isGoogleChat(card) {
            guard chatWebOpened[card.id] == nil else { continue }
            let found = chatWeb.conversation(forTitle: card.title)
            guard let conversation = found, conversation.isUnread, opened.insert(conversation.id).inserted else {
                // Why nothing was opened, without names (spec GW-13).
                DiagnosticsLog.append("google-chat-web", "card opened: matched=\(found != nil) unread=\(found?.isUnread == true)")
                continue
            }
            chatWebOpened[card.id] = conversation.id
            chatWebHeld[card.id] = .distantFuture
            guard card.sourceIdentifier == Self.chatWebSource, chatWebTexts[card.id] == nil else {
                chatWeb.markRead(title: card.title)
                continue
            }
            chatWebPending[conversation.id] = card.id
            let wanted = max(conversation.unreadCount ?? 1, Self.unreadCount(in: card.body) ?? 1)
            Task { [weak self] in
                let messages = await self?.chatWeb.openAndRead(conversationID: conversation.id)
                self?.fill(card.id, conversationID: conversation.id, from: messages, wanted: wanted)
            }
        }
    }

    /// The opened conversation's last messages go into its card: as many as were unread (1…8);
    /// none read in time, the card shows its count again (spec GW-17, GW-19).
    private func fill(_ cardID: Int64, conversationID: String, from messages: [ChatWebMessage]?, wanted: Int) {
        // Kept even when the card was closed meanwhile: it shows them when opened again (spec GW-17c).
        if chatWebPending[conversationID] == cardID { chatWebPending[conversationID] = nil }
        guard chatWebTexts[cardID] == nil else { return }
        let texts = (messages ?? []).suffix(min(max(wanted, 1), 8)).filter { !$0.text.isEmpty }
        guard !texts.isEmpty else {
            DiagnosticsLog.append("google-chat-web", "card messages not read in time")
            return
        }
        chatWebTexts[cardID] = Array(texts)
        DiagnosticsLog.append("notification-records", "Google Chat card filled from the web app: \(texts.count) message(s)")
    }

    /// Closed: the conversation stays read (the web app's menu for "Mark as unread" opens only
    /// in its active window), so the card goes as any read one (spec GW-17c, GW-7).
    func cardsClosed(_ cards: [AppNotification]) {
        if cards.contains(where: isAnswering) { answering = nil }
        for card in cards {
            guard let conversationID = chatWebOpened.removeValue(forKey: card.id) else { continue }
            if chatWebPending[conversationID] == card.id { chatWebPending[conversationID] = nil }
            chatWebHeld[card.id] = nil
        }
    }

    /// Every open card is closed with the notch.
    func allCardsClosed() {
        cardsClosed(recent.filter { chatWebOpened[$0.id] != nil })
        answering = nil
    }

    /// Answered: it stays read, and the card goes as any read one (spec GW-17, GW-7).
    func chatCardAnswered(_ notification: AppNotification) {
        for card in recent where chatWebOpened[card.id] != nil
            && GoogleChatJump.conversationName(from: card.title) == GoogleChatJump.conversationName(from: notification.title) {
            chatWebOpened[card.id] = nil
            chatWebHeld[card.id] = nil
        }
    }

    /// Whether the card belongs to the conversation being answered (spec E-32).
    func isAnswering(_ notification: AppNotification) -> Bool {
        guard let answering else { return false }
        if Self.sameConversation(answering, notification) { return true }
        let chat = { (card: AppNotification) in card.sourceIdentifier == Self.chatWebSource || self.isGoogleChat(card) }
        return chat(answering) && chat(notification)
            && GoogleChatJump.conversationName(from: answering.title) == GoogleChatJump.conversationName(from: notification.title)
    }

    /// Whether the card is still loading its messages from the web app (spec GW-17).
    func isLoadingChatTexts(_ notification: AppNotification) -> Bool {
        chatWebPending.values.contains(notification.id)
    }

    /// A Google Chat card can be marked read: the web app is read (spec GW-28).
    func canMarkChatRead(_ notification: AppNotification) -> Bool {
        chatWeb.state == .reading && (notification.sourceIdentifier == Self.chatWebSource || isGoogleChat(notification))
    }

    /// Reads the card's conversation in the web app, in the background, and removes the card (spec GW-28).
    func markChatRead(_ cards: [AppNotification]) {
        guard let card = cards.first else { return }
        chatWeb.markRead(title: card.title)
        cards.forEach { remove($0) }
    }

    /// "Open in Google Chat": the web app in front with the conversation, or the app (spec GW-19).
    func openInGoogleChat(_ notification: AppNotification) {
        if !chatWeb.openInApp(title: notification.title) { catalog.open(notification.appIdentifier) }
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
