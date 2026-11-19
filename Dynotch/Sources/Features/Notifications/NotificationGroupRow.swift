import SwiftUI

/// One sender's notifications in the Notifications feature (spec E-5b): closed it shows the
/// newest one; a click opens it with every message and a reply field.
struct NotificationGroupRow: View {
    /// Observed: messages loaded from the Google Chat web app redraw the card (spec GW-17c).
    @ObservedObject var service: NotificationService
    let group: NotificationGroup
    let isExpanded: Bool
    let toggle: () -> Void

    private var app: NotificationApp { service.catalog.app(for: group.latest.appIdentifier) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
                .contentShape(Rectangle())
                .onTapGesture(perform: toggle)
                .contextMenu { SnoozeMenu(service: service, notifications: group.notifications) }
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.notifications) { message($0) }
                }
                .padding(.leading, 36)
                if service.canReply(to: group.latest) {
                    NotificationReplyField(service: service, target: group.latest)
                        .padding(.leading, 36)
                        .padding(.bottom, 8)
                } else {
                    openButton
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(10), style: .continuous)
            .fill(Color.white.level(isExpanded ? 0.1 : 0.07)))
        // A Google Chat card opened reads its conversation; closed without a reply it is unread again (spec GW-17).
        // Only a real change closes: a row appearing closed must not mark a just-opened one unread.
        .onAppear { if isExpanded { service.cardOpened(group.notifications) } }
        .onChange(of: isExpanded) { _, open in
            if open { service.cardOpened(group.notifications) } else { service.cardsClosed(group.notifications) }
        }
    }

    private var header: some View {
        let content = service.content(for: group.latest)
        return HStack(alignment: .top, spacing: 10) {
            AppIconView(app: app, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(content.sender)
                        .font(.notch(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if group.notifications.count > 1 {
                        Text("\(group.notifications.count)")
                            .font(.notch(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.level(0.2)))
                    }
                    Spacer(minLength: 8)
                    Text("\(app.name) · \(group.latest.date.formatted(date: .omitted, time: .shortened))")
                        .font(.notch(size: 10))
                        .foregroundStyle(Color.white.level(0.45))
                        .lineLimit(1)
                    // Like the pop-up's header: the bin removes, the small X closes (spec E-5c).
                    NotificationHeaderButton(symbol: "trash", help: "Remove") {
                        withAnimation(.easeOut(duration: 0.2)) { group.notifications.forEach { service.remove($0) } }
                    }
                    if isExpanded {
                        NotificationHeaderButton(symbol: "xmark", help: "Close", action: toggle)
                    }
                }
                if !isExpanded, !content.detail.isEmpty {
                    Text(content.detail)
                        .font(.notch(size: 12))
                        .foregroundStyle(Color.white.level(0.8))
                        .lineLimit(2)
                }
            }
        }
        .help(isExpanded ? "Close" : "Open the messages and reply")
    }

    private func message(_ notification: AppNotification) -> some View {
        let loading = service.isLoadingChatTexts(notification)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            (loading ? Text("Loading messages…") : service.content(for: notification).detailText())
                .font(.notch(size: 12))
                .foregroundStyle(Color.white.level(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(notification.date.formatted(date: .omitted, time: .shortened))
                .font(.notch(size: 10))
                .monospacedDigit()
                .foregroundStyle(Color.white.level(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(9), style: .continuous).fill(Color.white.level(0.08)))
    }

    /// For apps that cannot be answered from here (mail, system notices).
    private var openButton: some View {
        let isChat = service.isGoogleChat(group.latest)
        return Button {
            // Google Chat: the web app in front with this conversation (spec GW-19).
            if isChat { service.openInGoogleChat(group.latest) } else { service.catalog.open(group.latest.appIdentifier) }
        } label: {
            Label(isChat ? "Open in Google Chat" : "Open \(app.name)", systemImage: "arrow.up.forward.app")
                .font(.notch(size: 11, weight: .medium))
                .foregroundStyle(Color.white.level(0.75))
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).fill(Color.white.level(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .padding(.leading, 36)
    }
}

/// "Remind me later" for notifications (spec E-19).
struct SnoozeMenu: View {
    let service: NotificationService
    let notifications: [AppNotification]

    var body: some View {
        ForEach(SnoozeChoice.allCases, id: \.self) { choice in
            Button(choice.title) { service.snooze(notifications, choice) }
        }
    }
}
