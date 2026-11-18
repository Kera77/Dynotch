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
}
