import Foundation

/// Where the Gmail notch content comes from (spec GM-12).
enum MailSource: String, CaseIterable, Sendable {
    /// Sender and subject read from Gmail's notifications (spec E-7, B-10d).
    case notifications
    /// The unread messages of the accounts set up in Apple Mail (spec GM-1…GM-11).
    case appleMail

    var title: String {
        switch self {
        case .notifications: "Notifications"
        case .appleMail: "Apple Mail"
        }
    }
}

/// One unread message in an account's Inbox (spec GM-4): no body, only the headers.
struct MailMessage: Identifiable, Equatable, Sendable {
    /// The Message-ID header, without the angle brackets.
    let id: String
    let account: String
    let sender: String
    let subject: String
    let date: Date
}

/// An account of Apple Mail with its Inbox's unread messages (spec GM-3, GM-4).
struct MailAccount: Identifiable, Equatable, Sendable {
    let name: String
    let isGmail: Bool
    /// The real number of unread messages, more than `messages` may hold.
    let unread: Int
    let messages: [MailMessage]

    var id: String { name }
    var more: Int { max(unread - messages.count, 0) }
}

/// An account as Mail names it; its id is the folder (and the mailbox URLs' host) in Mail's data.
struct MailAccountInfo: Equatable, Sendable {
    let id: String
    let name: String
    let isGmail: Bool
}

/// One unread message as Mail's index holds it (spec GM-13).
struct MailRow: Equatable, Sendable {
    let messageID: String
    let address: String
    let displayName: String
    let subject: String
    /// Seconds since 1970 (or since 2001 on an older index).
    let received: Double
}

/// Reads what Mail's account script and index return.
enum MailParser {
    static let messageLimit = 50

    /// Separators of the account script's output: records, fields.
    static let recordSeparator = Character(UnicodeScalar(30))
    static let fieldSeparator = Character(UnicodeScalar(31))

    /// One record per account: id, name, server, addresses joined by commas, enabled. Only the
    /// enabled ones come back; nil when the output is not in this form.
    static func accountInfos(from data: Data) -> [MailAccountInfo]? {
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) else { return nil }
        if text.isEmpty { return [] }
        var infos: [MailAccountInfo] = []
        for record in text.split(separator: recordSeparator) {
            let fields = record.split(separator: fieldSeparator, omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 5, !fields[0].isEmpty else { return nil }
            guard fields[4].trimmingCharacters(in: .whitespaces) != "false" else { continue }
            let addresses = fields[3].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            infos.append(MailAccountInfo(id: fields[0], name: fields[1], isGmail: isGmail(server: fields[2], addresses: addresses)))
        }
        return infos
    }

    /// The account's group: the newest unread messages, and the real count (spec GM-4).
    static func account(_ info: MailAccountInfo, unread: Int, rows: [MailRow]) -> MailAccount {
        let messages = rows
            .map { row in
                MailMessage(
                    id: row.messageID.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")),
                    account: info.name,
                    sender: row.displayName.isEmpty ? senderName(row.address) : row.displayName,
                    subject: row.subject,
                    date: date(received: row.received)
                )
            }
            .sorted { $0.date > $1.date }
        return MailAccount(
            name: info.name, isGmail: info.isGmail, unread: max(unread, messages.count), messages: Array(messages.prefix(messageLimit))
        )
    }

    /// Mail's index keeps seconds since 1970; a value too small for that counts from 2001.
    static func date(received: Double) -> Date {
        received < 1_200_000_000 ? Date(timeIntervalSinceReferenceDate: received) : Date(timeIntervalSince1970: received)
    }

    /// The account id and whether the mailbox is its Inbox, from a URL like "imap://ID/INBOX".
    static func inboxAccount(url: String) -> String? {
        guard let schemeEnd = url.range(of: "://") else { return nil }
        let parts = url[schemeEnd.upperBound...].split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return nil }
        let name = String(parts[1]).removingPercentEncoding ?? String(parts[1])
        return name.caseInsensitiveCompare("INBOX") == .orderedSame ? String(parts[0]) : nil
    }

    /// The account of a mailbox with this name ("imap://ABC/Primary", label "Primary"; a nested
    /// label "Work/Primary" too), case-insensitive; nil for any other mailbox (spec GM-16).
    static func labelAccount(url: String, label: String) -> String? {
        let wanted = label.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty, let schemeEnd = url.range(of: "://") else { return nil }
        let parts = url[schemeEnd.upperBound...].split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 2, !parts[0].isEmpty else { return nil }
        let path = parts.dropFirst().joined(separator: "/")
        let name = path.removingPercentEncoding ?? path
        return name.caseInsensitiveCompare(wanted) == .orderedSame ? String(parts[0]) : nil
    }

    /// Google's IMAP server, or a Gmail address.
    static func isGmail(server: String, addresses: [String]) -> Bool {
        let server = server.lowercased()
        if server.contains("gmail") || server.contains("googlemail") { return true }
        return addresses.contains { $0.lowercased().hasSuffix("@gmail.com") || $0.lowercased().hasSuffix("@googlemail.com") }
    }

    /// "Anna Kovács <anna@example.com>" → "Anna Kovács"; a bare address stays.
    static func senderName(_ sender: String) -> String {
        let trimmed = sender.trimmingCharacters(in: .whitespaces)
        guard let open = trimmed.firstIndex(of: "<"), open > trimmed.startIndex else {
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
        }
        let name = trimmed[..<open].trimmingCharacters(in: CharacterSet(charactersIn: " \""))
        return name.isEmpty ? trimmed : name
    }

    /// Mail's accounts only: no mailbox and no message is asked for, so Mail answers at once even
    /// with a huge Inbox (spec GM-13). Never changes anything in Mail (spec GM-2).
    static let accountScript = """
    on run
      set US to character id 31
      set RS to character id 30
      set out to {}
      tell application "Mail"
        repeat with acc in every account
          set isOn to true
          try
            set isOn to enabled of acc
          end try
          set srv to ""
          try
            set srv to my clean(server name of acc)
          end try
          set addressText to ""
          try
            set AppleScript's text item delimiters to ","
            set addressText to (email addresses of acc) as text
          end try
          set end of out to my clean(id of acc) & US & my clean(name of acc) & US & srv & US & addressText & US & (isOn as text)
        end repeat
      end tell
      set AppleScript's text item delimiters to RS
      return out as text
    end run

    on clean(v)
      if v is missing value then return ""
      return v as text
    end clean
    """
}
