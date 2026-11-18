import Foundation

extension NotificationService {
    /// Sends a reply: Beeper through its API, other chats by typing into the conversation.
    /// - Returns: a short note on how it was sent.
    /// - Parameter quoting: the line answered (spec E-17); Beeper links the answer to it, other
    ///   apps get the text alone.
    func reply(to notification: AppNotification, text: String, quoting: String? = nil) async throws -> String {
        if notification.appIdentifier.lowercased().contains("beeper") {
            try await BeeperClient().reply(to: notification.title, text: text, quoting: quoting)
            return "Sent"
        }
        let source = notification.sourceIdentifier ?? notification.appIdentifier
        let isGoogleChat = notification.site == "chat.google.com"
            || catalog.app(for: notification.appIdentifier).name.lowercased().contains("google chat")
        return try await TypedReply.send(
            text, link: notification.link, sourceApp: source, fallbackApp: notification.appIdentifier,
            conversation: isGoogleChat ? notification.title : nil
        )
    }

    // MARK: - Pop-up with the message (spec E-22, E-23)

    /// Whether the pop-up of this notification shows its text: the source's rule, else the
    /// general setting.
    func peekShowsMessage(_ notification: AppNotification) -> Bool {
        rule(for: catalog.app(for: notification.appIdentifier)).peekShowsMessage ?? preferences.peekShowsMessage
    }

    /// The texts the pop-up shows, oldest first: this conversation's new messages.
    func peekTexts(for notification: AppNotification) -> [String] {
        related(to: notification).map { content(for: $0).detail }
    }

    /// The pop-up's size: the small one, or as tall as its messages need.
    func peekSize(in geometry: NotchGeometry) -> CGSize {
        guard let peek, peekShowsMessage(peek) else { return geometry.peekSize }
        let height = NotificationTextLayout.peekHeight(
            texts: peekTexts(for: peek), notchHeight: geometry.notchSize.height, maxLines: preferences.peekLines
        )
        return CGSize(width: max(geometry.peekSize.width, NotificationTextLayout.peekWidth), height: height)
    }

    /// The hovered card's height for these messages, every text in full (spec E-23).
    func stackHeight(for notifications: [AppNotification], notchHeight: CGFloat) -> CGFloat {
        NotificationTextLayout.stackHeight(texts: notifications.map { content(for: $0).detail }, notchHeight: notchHeight)
    }
}
