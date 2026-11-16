import SwiftUI

/// One sender's new messages, shown when the peek is hovered (spec E-4): the sender once on
/// top, the texts one under the other, and a reply field for apps that can be answered (spec E-11).
struct NotificationStackView: View {
    @ObservedObject var service: NotificationService
    let notifications: [AppNotification]
    let canReply: Bool
    let notchHeight: CGFloat
    /// Closes the card; its messages count as seen (spec E-12).
    var close: () -> Void = {}
    /// Removes every notification and closes the card (spec E-12).
    var clearAll: () -> Void = {}

    @State private var replyText = ""
    @State private var replyStatus: ReplyStatus = .idle

    enum ReplyStatus: Equatable {
        case idle
        case sending
        case sent(String)
        case failed(String)
    }

    /// The reply goes to the newest message's chat.
    private var replyTarget: AppNotification? { notifications.last }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            if let latest = notifications.last {
                header(for: latest)
            }
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(notifications) { notification in
                            message(notification)
                                .id(notification.id)
                        }
                    }
                    .padding(.leading, 50)
                    .padding(.trailing, 14)
                }
                .scrollIndicators(.never)
                .onAppear {
                    if let last = notifications.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            if canReply {
                replyField
            } else if let latest = notifications.last {
                openToReply(latest)
            }
        }
    }

    /// For apps without a reply API (e.g. Google Chat): one click to the app instead.
    private func openToReply(_ notification: AppNotification) -> some View {
        let app = service.catalog.app(for: notification.appIdentifier)
        return Button {
            service.catalog.open(notification.appIdentifier)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                Text("Open \(app.name) to reply")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.75))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    /// Icon, sender and app, once for all messages.
    private func header(for notification: AppNotification) -> some View {
        let app = service.catalog.app(for: notification.appIdentifier)
        return HStack(spacing: 10) {
            AppIconView(app: app, size: 28)
            Text(service.content(for: notification).sender)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(app.name)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.45))
                .lineLimit(1)
            NotificationHeaderButton(symbol: "trash", help: "Clear all notifications", action: clearAll)
            NotificationHeaderButton(symbol: "xmark", help: "Close", action: close)
        }
        .padding(.horizontal, 12)
        .frame(height: NotchGeometry.notificationHeaderHeight)
        .contentShape(Rectangle())
        .onTapGesture { service.catalog.open(notification.appIdentifier) }
        .help("Open \(app.name)")
    }

    /// One message: its text and time, without repeating the sender.
    private func message(_ notification: AppNotification) -> some View {
        let detail = service.content(for: notification).detail
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(detail.isEmpty ? "—" : detail)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(notification.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.08)))
    }

    private var replyField: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $replyText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.1)))
                .onSubmit(send)
                .disabled(replyStatus == .sending)
            Button(action: send) {
                Group {
                    switch replyStatus {
                    case .sending: ProgressView().controlSize(.small)
                    case .sent: Image(systemName: "checkmark")
                    default: Image(systemName: "paperplane.fill")
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(red: 0.04, green: 0.52, blue: 1)))
            }
            .buttonStyle(.plain)
            .disabled(replyText.trimmingCharacters(in: .whitespaces).isEmpty || replyStatus == .sending)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .overlay(alignment: .bottomLeading) {
            if let note = statusNote {
                Text(note.text)
                    .font(.system(size: 10))
                    .foregroundStyle(note.isError ? Color(red: 1, green: 0.45, blue: 0.4) : Color.white.opacity(0.5))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .offset(y: 2)
            }
        }
    }

    private var statusNote: (text: String, isError: Bool)? {
        switch replyStatus {
        case .failed(let message): (message, true)
        case .sent(let note): (note, false)
        default: nil
        }
    }

    private var placeholder: String {
        guard let target = replyTarget else { return "Reply…" }
        return "Reply to \(service.content(for: target).sender)…"
    }

    private func send() {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let target = replyTarget, replyStatus != .sending else { return }
        replyStatus = .sending
        Task {
            do {
                let note = try await service.reply(to: target, text: text)
                replyText = ""
                replyStatus = .sent(note)
            } catch {
                replyStatus = .failed("\(error)")
            }
        }
    }
}
