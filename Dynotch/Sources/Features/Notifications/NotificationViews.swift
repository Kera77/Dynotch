import SwiftUI

struct AppIconView: View {
    let app: NotificationApp
    let size: CGFloat

    var body: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "bell.fill")
                .font(.system(size: size * 0.6))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
    }
}

/// The closed notch opened just a little: who wrote, in which app, and how many are new (spec E-3).
struct NotificationPeekView: View {
    let app: NotificationApp
    let content: NotificationContent
    let notchHeight: CGFloat
    var newCount = 1

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 6) {
                AppIconView(app: app, size: 16)
                Text(content.sender)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if content.sender != app.name {
                    Text(app.name)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)
                        .layoutPriority(-1)
                }
                if newCount > 1 {
                    Text("+\(newCount - 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                        .help("\(newCount) new notifications")
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

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

/// Notifications feature: what arrived since launch, newest first (spec E-4, E-5).
struct NotificationsFeatureView: View {
    @ObservedObject var service: NotificationService
    /// Looking at the list counts as having seen the new notifications.
    var isActive = false

    var body: some View {
        Group { content }
            .onChange(of: isActive) { _, active in
                if active { service.markSeen() }
            }
    }

    @ViewBuilder private var content: some View {
        switch service.status {
        case .running:
            if service.recent.isEmpty {
                message(symbol: "bell", text: "No new notifications")
            } else {
                list
            }
        case .noAccess:
            prompt(
                text: "Reading notifications needs Full Disk Access.\nAdd Dynotch, then restart it.",
                button: "Open System Settings",
                action: service.openFullDiskAccessSettings
            )
        case .unsupported:
            message(symbol: "exclamationmark.triangle", text: "Notifications can't be read on this system.")
        case .disabled:
            message(symbol: "bell.slash", text: "Notifications are turned off")
        }
    }

    private var list: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(service.recent.count) notification\(service.recent.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { service.clearAll() }
                } label: {
                    Label("Clear all", systemImage: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
            ScrollView(.vertical) {
                VStack(spacing: 6) {
                    ForEach(service.recent) { notification in
                        NotificationRow(
                            app: service.catalog.app(for: notification.appIdentifier),
                            content: service.content(for: notification),
                            date: notification.date
                        ) {
                            withAnimation(.easeOut(duration: 0.2)) { service.remove(notification) }
                        }
                        .onTapGesture { service.catalog.open(notification.appIdentifier) }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.never)
        }
    }

    private func message(symbol: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 16))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(Color.white.opacity(0.55))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func prompt(text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(button, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NotificationRow: View {
    let app: NotificationApp
    let content: NotificationContent
    let date: Date
    /// Removes the notification (spec E-12).
    var remove: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AppIconView(app: app, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(content.sender)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(app.name) · \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                    NotificationHeaderButton(symbol: "xmark", help: "Remove", action: remove)
                }
                if !content.detail.isEmpty {
                    Text(content.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.07)))
        .contentShape(Rectangle())
        .help("Open \(app.name)")
    }
}

/// Small round icon button (close, clear all).
struct NotificationHeaderButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
