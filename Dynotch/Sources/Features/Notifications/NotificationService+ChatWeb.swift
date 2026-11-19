import Foundation

// Google Chat read from its web app (spec GW-5…GW-8).
extension NotificationService {
    /// How long a Google Chat notification stays without its conversation ever looking unread
    /// (it may have been read in the web app right away).
    private nonisolated static let unreadGrace: TimeInterval = 90

    func startChatWeb() {
        chatWeb.onSnapshot = { [weak self] snapshot in self?.dropReadInChat(snapshot) }
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

    /// Read: not unread now, and either seen unread since the message came, or long enough ago.
    nonisolated static func isRead(
        _ conversation: ChatWebConversation, notifiedAt date: Date, lastSeenUnread: Date?, now: Date
    ) -> Bool {
        guard !conversation.isUnread else { return false }
        if let lastSeenUnread, lastSeenUnread >= date { return true }
        return now.timeIntervalSince(date) > unreadGrace
    }
}
