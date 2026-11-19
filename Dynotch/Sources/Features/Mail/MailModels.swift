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

/// Reads what the Mail script returns.
enum MailParser {
    static let messageLimit = 50

    private struct RawAccount: Decodable {
        let name: String
        let server: String
        let addresses: [String]
        let unread: Int
        let messages: [RawMessage]
    }

    private struct RawMessage: Decodable {
        let id: String
        let sender: String
        let subject: String
        let date: Double
    }

    static func accounts(from data: Data) -> [MailAccount]? {
        guard let raw = try? JSONDecoder().decode([RawAccount].self, from: data) else { return nil }
        return raw.map { account in
            let messages = account.messages
                .map { message in
                    MailMessage(
                        id: message.id.trimmingCharacters(in: CharacterSet(charactersIn: "<> ")),
                        account: account.name, sender: senderName(message.sender), subject: message.subject,
                        date: Date(timeIntervalSince1970: message.date / 1000)
                    )
                }
                .sorted { $0.date > $1.date }
            return MailAccount(
                name: account.name, isGmail: isGmail(server: account.server, addresses: account.addresses),
                unread: max(account.unread, messages.count), messages: Array(messages.prefix(messageLimit))
            )
        }
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

    /// Reads every enabled account's Inbox: counts and the newest unread headers. Never changes
    /// anything in Mail (spec GM-2).
    static let script = """
    function run() {
      const Mail = Application('Mail');
      const out = [];
      for (const acc of Mail.accounts()) {
        let enabled = true;
        try { enabled = acc.enabled(); } catch (e) {}
        if (!enabled) continue;
        let server = '';
        try { server = acc.serverName() || ''; } catch (e) {}
        let addresses = [];
        try { addresses = acc.emailAddresses() || []; } catch (e) {}
        let box = null;
        for (const name of ['INBOX', 'Inbox']) {
          try { const b = acc.mailboxes.byName(name); b.name(); box = b; break; } catch (e) {}
        }
        let unread = 0;
        const messages = [];
        if (box) {
          try { unread = box.unreadCount(); } catch (e) {}
          if (unread > 0) {
            const found = box.messages.whose({ readStatus: false });
            const ids = found.messageId(), senders = found.sender(), subjects = found.subject(), dates = found.dateReceived();
            const order = dates.map((d, i) => i).sort((a, b) => dates[b] - dates[a]).slice(0, \(messageLimit));
            for (const i of order) {
              messages.push({ id: ids[i] || '', sender: senders[i] || '', subject: subjects[i] || '', date: dates[i].getTime() });
            }
          }
        }
        out.push({ name: acc.name(), server: server, addresses: addresses, unread: unread, messages: messages });
      }
      return JSON.stringify(out);
    }
    """
}
