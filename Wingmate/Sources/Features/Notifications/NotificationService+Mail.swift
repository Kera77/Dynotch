import Foundation

// Gmail and other accounts read from Apple Mail (spec GM-5, GM-6, GM-7, GM-12).
extension NotificationService {
    func isGmail(_ notification: AppNotification) -> Bool {
        if notification.site == "mail.google.com" { return true }
        return catalog.app(for: notification.appIdentifier).name.lowercased().contains("gmail")
    }

    /// A Gmail or Mail notification: Mail is read at once (spec GM-5).
    func mailNoticed(_ incoming: [AppNotification]) {
        guard mail.isActive else { return }
        if incoming.contains(where: { isGmail($0) || $0.appIdentifier.lowercased() == MailService.mailBundleID }) {
            mail.refresh()
        }
    }

    /// With Mail as the source, Gmail's notifications are not listed: Mail's rows stand for
    /// them, so nothing shows twice (spec GM-6, GM-12).
    func isShownByMail(_ notification: AppNotification) -> Bool {
        mail.isActive && mail.state == .reading && isGmail(notification)
    }

    /// The Gmail badge counts Mail's unread Gmail messages (spec GM-7); nil: the Dock's own.
    func mailBadgeLabel(for app: BadgeApp) -> String? {
        guard mail.isActive, Self.isGmailApp(app), let count = mail.gmailUnread else { return nil }
        return count > 0 ? String(count) : ""
    }

    nonisolated static func isGmailApp(_ app: BadgeApp) -> Bool {
        app.name.lowercased().contains("gmail") && app.bundleID.lowercased() != MailService.mailBundleID
    }

    /// The Gmail badge's hover list: Mail's unread Gmail messages (spec GM-7).
    func mailBadgeRows(for app: BadgeApp) -> [BadgeNotificationRow]? {
        guard mail.isActive, mail.state == .reading, Self.isGmailApp(app) else { return nil }
        let messages = mail.shownAccounts.filter(\.isGmail).flatMap(\.messages).sorted { $0.date > $1.date }
        return messages.enumerated().map { index, message in
            BadgeNotificationRow(id: -10_000 - Int64(index), sender: message.sender, detail: message.subject, date: message.date)
        }
    }
}
