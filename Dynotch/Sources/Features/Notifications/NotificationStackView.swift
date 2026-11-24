import SwiftUI

/// One sender's new messages, shown when the peek is hovered (spec E-4): the sender once on
/// top, the texts one under the other, and a reply field for apps that can be answered (spec E-11).
struct NotificationStackView: View {
    var service: NotificationService
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
    /// A click on a message puts the typing into the reply field (spec E-27).
    @State private var focusRequest = 0

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
                    // Long cards start at the top and scroll down (spec E-23).
                    if let first = notifications.first { proxy.scrollTo(first.id, anchor: .top) }
                }
            }
            if canReply, let replyTarget {
                NotificationReplyField(
                    service: service, target: replyTarget, quote: replyingTo,
                    cancelQuote: { replyingTo = nil },
                    focusRequest: focusRequest,
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
            .font(.notch(size: 12, weight: .medium))
            .foregroundStyle(Color.white.level(0.75))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).fill(Color.white.level(0.08)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
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
                .font(.notch(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(app.name)
                .font(.notch(size: 10))
                .foregroundStyle(Color.white.level(0.45))
                .lineLimit(1)
            Menu {
                SnoozeMenu(service: service, notifications: notifications)
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.notch(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.level(0.6))
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.button)
            .buttonStyle(.notch)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Remind me later")
            .accessibilityLabel("Remind me later")
            NotificationHeaderButton(symbol: "xmark", help: "Clear all notifications", action: clearAll)
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
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            service.content(for: notification).detailText()
                .font(.notch(size: 13))
                .foregroundStyle(Color.white.level(0.9))
                // Hovered, the whole text shows (spec E-23).
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(notification.date.formatted(date: .omitted, time: .shortened))
                .font(.notch(size: 10))
                .monospacedDigit()
                .foregroundStyle(Color.white.level(0.4))
            if canReply {
                Button {
                    replyingTo = notification
                } label: {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.notch(size: 10))
                        .foregroundStyle(replyingTo?.id == notification.id ? Self.blue : Color.white.level(0.6))
                        .frame(width: 18, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.notch)
                .help("Answer this line")
                .accessibilityLabel("Answer this line")
                .opacity(hoveredLine == notification.id || replyingTo?.id == notification.id ? 1 : 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: AppleStyle.corner(10), style: .continuous)
                .fill(Color.white.level(replyingTo?.id == notification.id ? 0.14 : 0.08))
        )
        .contentShape(Rectangle())
        .onTapGesture { if canReply { focusRequest += 1 } }
        .onHover { hovering in
            if hovering {
                hoveredLine = notification.id
            } else if hoveredLine == notification.id {
                hoveredLine = nil
            }
        }
    }

    private static var blue: Color { Theme.blue }

    /// My answer to a line, on the right like in chat apps.
    private func answerBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 40)
            Text(text)
                .font(.notch(size: 13))
                .foregroundStyle(.white)
                .lineLimit(3)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: AppleStyle.corner(10), style: .continuous).fill(Self.blue))
        }
    }
}
