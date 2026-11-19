import SwiftUI

/// The chosen Mail accounts' unread messages, one group per account (spec GM-6). Under All only
/// the newest few per account; the Mail tab lists them all.
struct MailUnreadList: View {
    @ObservedObject var mail: MailService
    /// At most this many rows per account; nil: all.
    var limit: Int?

    var body: some View {
        ForEach(mail.shownAccounts) { account in
            if account.unread > 0 || limit == nil {
                VStack(alignment: .leading, spacing: 2) {
                    header(account)
                    let rows = limit.map { Array(account.messages.prefix($0)) } ?? account.messages
                    ForEach(rows) { message in
                        MailMessageRow(message: message) { mail.open(message) }
                    }
                    let more = account.unread - rows.count
                    if more > 0 {
                        Text("+\(more) more")
                            .font(.notch(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.level(0.45))
                            .padding(.leading, 8)
                            .padding(.top, 2)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: AppleStyle.corner(10), style: .continuous).fill(Color.white.level(0.07)))
            }
        }
    }

    private func header(_ account: MailAccount) -> some View {
        HStack(spacing: 6) {
            Image(systemName: account.isGmail ? "envelope.fill" : "tray.fill")
                .font(.notch(size: 11, weight: .semibold))
            Text(account.name)
                .font(.notch(size: 12, weight: .semibold))
            Text(account.unread == 0 ? "No unread mail" : "\(account.unread) unread")
                .font(.notch(size: 11, weight: .medium))
                .foregroundStyle(Color.white.level(0.5))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }
}

/// One unread message: sender, subject and when it came; a click opens it (spec GM-8).
struct MailMessageRow: View {
    let message: MailMessage
    let open: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: open) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(message.sender)
                        .font(.notch(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(message.subject.isEmpty ? "(no subject)" : message.subject)
                        .font(.notch(size: 12))
                        .foregroundStyle(Color.white.level(0.7))
                }
                .lineLimit(1)
                Spacer(minLength: 8)
                Text(MailFormat.when(message.date))
                    .font(.notch(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.level(0.45))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.level(isHovered ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// The Mail tab: every unread message of the chosen accounts, or why there is none (spec GM-6, GM-11).
struct MailTabView: View {
    @ObservedObject var mail: MailService

    var body: some View {
        if mail.state == .reading, !mail.shownAccounts.isEmpty {
            ScrollView(.vertical) {
                VStack(spacing: 6) { MailUnreadList(mail: mail) }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
            }
            .scrollIndicators(.never)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "envelope")
                    .font(.notch(size: 22))
                Text(MailFormat.status(mail))
                    .font(.notch(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color.white.level(0.6))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

enum MailFormat {
    /// "10:24" today, "Tue" this week, "Nov 3" before.
    static func when(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return date.formatted(date: .omitted, time: .shortened) }
        if let days = calendar.dateComponents([.day], from: date, to: now).day, days < 6 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// What the settings and the empty tab say (spec GM-11).
    @MainActor
    static func status(_ mail: MailService) -> String {
        switch mail.state {
        case .off: "Off"
        case .notRunning: "Mail isn't running"
        case .noAccess: "Needs Automation access to Mail"
        case .noAccounts: "No accounts in Mail"
        case .failed: "Mail didn't answer"
        case .reading:
            mail.shownAccounts.isEmpty ? "No account chosen" : "Reading · \(mail.totalUnread) unread"
        }
    }
}
