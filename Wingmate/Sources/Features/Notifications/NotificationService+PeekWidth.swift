import AppKit

// MARK: - As narrow as the closed notch when it fits (spec E-31)

extension NotificationService {
    /// What the pop-up's content needs side to side: the name row, its messages and the row
    /// under it (spec E-22, E-28).
    func peekContentWidth(_ notification: AppNotification) -> CGFloat {
        let app = catalog.app(for: notification.appIdentifier)
        let content = content(for: notification)
        var name = 14 + 16 + 6 + PeekText.width(content.sender, size: 12, weight: .semibold) + 14
        if content.sender != app.name { name += 6 + PeekText.width(app.name, size: 11) }
        let shown = peekSecondRow.map { if case .notification = $0 { 2 } else { 1 } } ?? 1
        let newCount = max(unseen.count - (shown - 1), 1)
        if newCount > 1 { name += 6 + PeekText.width("+\(newCount - 1)", size: 10, weight: .semibold) + 12 }
        var width = name
        if peekShowsMessage(notification) {
            for text in peekTexts(for: notification) {
                width = max(width, 14 + 22 + PeekText.width(text.isEmpty ? "—" : text, size: 12) + 14)
            }
        }
        if let row = peekSecondRow { width = max(width, secondRowWidth(row)) }
        return width
    }

    private func secondRowWidth(_ row: PeekSecondRow) -> CGFloat {
        switch row {
        case .notification(let item):
            let app = catalog.app(for: item.appIdentifier)
            let content = content(for: item)
            let subtitle = content.sender == app.name ? 0 : 6 + PeekText.width(app.name, size: 11)
            return 14 + 14 + 6 + PeekText.width(content.sender, size: 12, weight: .semibold) + subtitle + 14
        case .notice(let notice):
            let subtitle = [notice.detail, notice.date.formatted(date: .omitted, time: .shortened)]
                .filter { !$0.isEmpty }.joined(separator: " · ")
            return 14 + 16 + 6 + PeekText.width(notice.title, size: 12, weight: .semibold) + 6 + PeekText.width(subtitle, size: 11) + 14
        }
    }
}

/// Text widths for the rows hanging under the notch, a little slack for SwiftUI's rounding.
enum PeekText {
    static func width(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular) -> CGFloat {
        IndicatorLayout.textWidth(text, size: AppleStyle.textSize(size), weight: weight) + 2
    }
}
