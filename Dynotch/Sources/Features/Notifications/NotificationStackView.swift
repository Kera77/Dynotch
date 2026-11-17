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

    /// The reply goes to the newest message's chat.
    private var replyTarget: AppNotification? { notifications.last }

    /// A line answered on its own (spec E-17).
    @State private var replyingTo: AppNotification?
    @State private var hoveredLine: Int64?
    /// Answers to single lines, shown under them while the card is open.
    @State private var answers: [Answer] = []

    struct Answer: Identifiable {
        let id = UUID()
        let line: Int64
        let text: String
    }

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
                            ForEach(answers.filter { $0.line == notification.id }) { answer in
                                answerBubble(answer.text)
                                    .id(answer.id)
                            }
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
            if canReply, let replyTarget {
                NotificationReplyField(
                    service: service, target: replyTarget, quote: replyingTo,
                    cancelQuote: { replyingTo = nil },
                    sent: { text in
                        // A line's answer joins the conversation and the card stays open; an
                        // answer to the whole conversation closes it (spec E-17).
                        if let line = replyingTo {
                            answers.append(Answer(line: line.id, text: text))
                            replyingTo = nil
                        } else {
                            close()
                        }
                    }
                )
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
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
            if canReply {
                Button {
                    replyingTo = notification
                } label: {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(replyingTo?.id == notification.id ? Self.blue : Color.white.opacity(0.6))
                        .frame(width: 18, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Answer this line")
                .opacity(hoveredLine == notification.id || replyingTo?.id == notification.id ? 1 : 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(replyingTo?.id == notification.id ? 0.14 : 0.08))
        )
        .onHover { hovering in
            if hovering {
                hoveredLine = notification.id
            } else if hoveredLine == notification.id {
                hoveredLine = nil
            }
        }
    }

    private static let blue = Color(red: 0.04, green: 0.52, blue: 1)

    /// My answer to a line, on the right like in chat apps.
    private func answerBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 40)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .lineLimit(3)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Self.blue))
        }
    }
}
