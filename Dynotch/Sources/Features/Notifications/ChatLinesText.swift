import SwiftUI

extension NotificationContent {
    /// The text to show: Google Chat messages line by line with the owner's own in blue, like a
    /// sent message (spec GW-20); otherwise the detail as it is.
    func detailText(placeholder: String = "—") -> Text {
        guard !lines.isEmpty else { return Text(detail.isEmpty ? placeholder : detail) }
        return lines.dropFirst().reduce(line(lines[0])) { text, next in Text("\(text)\n\(line(next))") }
    }

    private func line(_ message: ChatWebMessage) -> Text {
        if message.isMine { return Text(message.text).foregroundStyle(Theme.blue) }
        guard let name = shownSender(of: message) else { return Text(message.text) }
        return Text("\(Text("\(name): ").fontWeight(.semibold))\(message.text)")
    }

    /// In a group the sender stands before the line; in a direct message the card's title is
    /// the sender already (spec GW-32).
    func shownSender(of message: ChatWebMessage) -> String? {
        guard let name = message.sender, !name.isEmpty, !sender.hasPrefix(name) else { return nil }
        return name
    }
}
