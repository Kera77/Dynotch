import SwiftUI

extension NotificationContent {
    /// The text to show: Google Chat messages line by line with the owner's own in blue, like a
    /// sent message (spec GW-20); otherwise the detail as it is.
    func detailText(placeholder: String = "—") -> Text {
        guard !lines.isEmpty else { return Text(detail.isEmpty ? placeholder : detail) }
        return lines.dropFirst().reduce(line(lines[0])) { text, next in Text("\(text)\n\(line(next))") }
    }

    private func line(_ message: ChatWebMessage) -> Text {
        message.isMine ? Text(message.text).foregroundStyle(Theme.blue) : Text(message.text)
    }
}
