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
        if isGoogleChat {
            // Straight into the web app's message box when it can be read (spec GW-9).
            do {
                let note = try await chatWeb.reply(text, toTitle: notification.title)
                // Answered: the conversation stays read (spec GW-17).
                chatCardAnswered(notification)
                return note
            } catch is GoogleChatWebService.Unavailable {
                // A readable web app never comes to the front: the text waits on the clipboard (spec GW-29).
                if chatWeb.state == .reading {
                    DiagnosticsLog.write("google-chat-web", "reply: not possible in the background, text copied")
                    TypedReply.copyToClipboard(text)
                    throw GoogleChatWebService.Failure(
                        description: "Couldn't reply in the background. Text copied: paste it in Google Chat."
                    )
                }
                DiagnosticsLog.write("google-chat-web", "reply: web app not usable, typing instead")
            }
        }
        let note = try await TypedReply.send(
            text, link: notification.link, sourceApp: source, fallbackApp: notification.appIdentifier,
            conversation: isGoogleChat ? notification.title : nil
        )
        if isGoogleChat { chatCardAnswered(notification) }
        return note
    }

    // MARK: - Pop-up with the message (spec E-22, E-23)

    /// Whether the pop-up of this notification shows its text: set per app, the name only by
    /// default (spec E-22b).
    func peekShowsMessage(_ notification: AppNotification) -> Bool {
        rule(for: catalog.app(for: notification.appIdentifier)).peekShowsMessage == true
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

    // MARK: - Conversations

    /// The new notifications from the same app and sender (or chat) as this one, oldest first
    /// (spec E-4).
    func related(to notification: AppNotification) -> [AppNotification] {
        let group = unseen.filter { Self.sameConversation($0, notification) }
        return group.isEmpty ? [notification] : group
    }

    nonisolated static func sameConversation(_ lhs: AppNotification, _ rhs: AppNotification) -> Bool {
        lhs.appIdentifier == rhs.appIdentifier
            && lhs.title.trimmingCharacters(in: .whitespaces).lowercased() == rhs.title.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
