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
    /// The conversation's web address, if the record carries one (spec E-11b).
    var link: URL?
    /// The app that posted it (e.g. the browser), before attributing it to a web app.
    var sourceIdentifier: String?

    func with(appIdentifier: String) -> AppNotification {
        var copy = AppNotification(
            id: id, appIdentifier: appIdentifier, title: title,
            subtitle: subtitle, body: body, date: date, site: site, link: link
        )
        copy.sourceIdentifier = sourceIdentifier ?? self.appIdentifier
        return copy
    }

    /// The same notification under another id (spec E-13b: kept after its record left).
    func with(id newID: Int64) -> AppNotification {
        var copy = AppNotification(
            id: newID, appIdentifier: appIdentifier, title: title,
            subtitle: subtitle, body: body, date: date, site: site, link: link
        )
        copy.sourceIdentifier = sourceIdentifier
        return copy
    }

    /// The same message posted again by its site.
    func repeats(_ other: AppNotification) -> Bool {
        isFromBrowser && appIdentifier == other.appIdentifier && title == other.title
            && subtitle == other.subtitle && body == other.body
    }

    /// Posted by a browser for a website: the page closes these itself after a few seconds,
    /// so leaving Notification Center says nothing about being read (spec E-13c). Web apps
    /// (Gmail, Google Chat added to the Dock) do the same (spec E-13d).
    var isFromBrowser: Bool {
        let source = sourceIdentifier ?? appIdentifier
        return WebNotificationSource.isShared(source) || WebNotificationSource.isWebApp(source)
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
        let body = withoutSourceLines(notification.body)
        let sender = notification.title.isEmpty ? appName : notification.title

        switch kind {
        case .mail:
            // Sender and subject only: the subject is the subtitle, or the first line of the body.
            let subject = subtitle.isEmpty ? firstLine(of: body) : subtitle
            return NotificationContent(sender: sender, detail: subject)
        case .message:
            let detail = [subtitle, body].filter { !$0.isEmpty }.joined(separator: "\n")
            return NotificationContent(sender: sender, detail: detail)
        }
    }

    /// Browsers and bridges add where a notification came from ("chat.google.com",
    /// "via chat.google.com", "via WhatsApp"); that is not worth showing (spec E-7b).
    static func isSourceLine(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let looksLikeDomain = !trimmed.contains(" ") && trimmed.contains(".")
        let isVia = trimmed.range(of: #"^via\s+\S+$"#, options: [.regularExpression, .caseInsensitive]) != nil
        return looksLikeDomain || isVia
    }

    private static func isMeaningful(subtitle: String) -> Bool {
        !subtitle.isEmpty && !isSourceLine(subtitle)
    }

    /// The body without lines that only name the source.
    static func withoutSourceLines(_ body: String) -> String {
        body.components(separatedBy: .newlines)
            .filter { !isSourceLine($0) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
            site: WebNotificationSource.site(in: plist),
            link: WebNotificationSource.conversationLink(in: plist)
        )
    }

    /// Key names only (no values), for the diagnostics log.
    static func keySummary(of data: Data) -> String {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return "not a dictionary plist (\(data.count) bytes)"
        }
        let requestDictionary = plist["req"] as? [String: Any] ?? [:]
        // userInfo ("usda") is often a nested property list.
        var userInfoKeys: [String] = []
        if let data = requestDictionary["usda"] as? Data,
           let nested = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            userInfoKeys = nested.keys.sorted()
        } else if let nested = requestDictionary["usda"] as? [String: Any] {
            userInfoKeys = nested.keys.sorted()
        }
        return "keys: \(plist.keys.sorted()) req: \(requestDictionary.keys.sorted()) usda: \(userInfoKeys) "
            + "usda strings: \(structuralStrings(in: requestDictionary["usda"]))"
    }

    /// Strings in the archived userInfo that look like identifiers or addresses (they contain "/"
    /// or ":"), with long runs masked, so the log shows their shape but no content.
    static func structuralStrings(in value: Any?) -> [String] {
        guard let data = value as? Data,
              let archive = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let objects = archive["$objects"] as? [Any]
        else { return [] }
        return objects.compactMap { $0 as? String }
            .filter { ($0.contains("/") || $0.contains(":")) && !$0.contains(" ") }
            .map { $0.replacingOccurrences(of: #"[A-Za-z0-9_-]{6,}"#, with: "…", options: .regularExpression) }
            .map { String($0.prefix(80)) }
    }

    private static func text(_ value: Any?) -> String {
        ((value as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
