import Foundation

/// A notification read from macOS Notification Center.
struct AppNotification: Identifiable, Equatable, Sendable {
    /// Record id in the Notification Center database.
    let id: Int64
    let appIdentifier: String
    let title: String
    let subtitle: String
    let body: String
    let date: Date
    /// Website the notification came from, if the record names one (web apps, Safari).
    var site: String?

    func with(appIdentifier: String) -> AppNotification {
        AppNotification(
            id: id, appIdentifier: appIdentifier, title: title,
            subtitle: subtitle, body: body, date: date, site: site
        )
    }
}

/// What the notch shows for a notification.
struct NotificationContent: Equatable, Sendable {
    /// Who wrote (shown in the peek).
    let sender: String
    /// Message text, or the subject for mail.
    let detail: String
}

enum NotificationKind: Equatable, Sendable {
    /// Mail: show sender and subject only.
    case mail
    case message

    static func detect(appName: String) -> NotificationKind {
        let name = appName.lowercased()
        return name.contains("gmail") || name == "mail" ? .mail : .message
    }
}

enum NotificationPresenter {
    static func content(for notification: AppNotification, appName: String, kind: NotificationKind) -> NotificationContent {
        let subtitle = isMeaningful(subtitle: notification.subtitle) ? notification.subtitle : ""
        let sender = notification.title.isEmpty ? appName : notification.title

        switch kind {
        case .mail:
            // Sender and subject only: the subject is the subtitle, or the first line of the body.
            let subject = subtitle.isEmpty ? firstLine(of: notification.body) : subtitle
            return NotificationContent(sender: sender, detail: subject)
        case .message:
            let detail = [subtitle, notification.body].filter { !$0.isEmpty }.joined(separator: "\n")
            return NotificationContent(sender: sender, detail: detail)
        }
    }

    /// Web notifications can carry the site's domain as subtitle; that is not worth showing.
    private static func isMeaningful(subtitle: String) -> Bool {
        guard !subtitle.isEmpty else { return false }
        let looksLikeDomain = !subtitle.contains(" ") && subtitle.contains(".")
        return !looksLikeDomain
    }

    private static func firstLine(of text: String) -> String {
        text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
    }
}

/// Decodes a record of the Notification Center database (a binary property list).
enum NotificationParser {
    static func parse(recordID: Int64, appIdentifier: String, data: Data) -> AppNotification? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        let request = plist["req"] as? [String: Any] ?? [:]
        let title = text(request["titl"])
        let subtitle = text(request["subt"])
        let body = text(request["body"])
        guard !(title.isEmpty && subtitle.isEmpty && body.isEmpty) else { return nil }

        let date = (plist["date"] as? Double).map(Date.init(timeIntervalSinceReferenceDate:)) ?? Date()
        let identifier = appIdentifier.isEmpty ? text(plist["app"]) : appIdentifier
        return AppNotification(
            id: recordID, appIdentifier: identifier,
            title: title, subtitle: subtitle, body: body, date: date,
            site: WebNotificationSource.site(in: plist)
        )
    }

    /// Key names only (no values), for the diagnostics log.
    static func keySummary(of data: Data) -> String {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return "not a dictionary plist (\(data.count) bytes)"
        }
        let request = (plist["req"] as? [String: Any])?.keys.sorted() ?? []
        return "keys: \(plist.keys.sorted()) req: \(request)"
    }

    private static func text(_ value: Any?) -> String {
        ((value as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
