import SwiftUI

/// One sender's notifications in the Notifications feature (spec E-5b): closed it shows the
/// newest one; a click opens it with every message and a reply field.
struct NotificationGroupRow: View {
    let service: NotificationService
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
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(isExpanded ? 0.1 : 0.07)))
    }

    private var header: some View {
        let content = service.content(for: group.latest)
        return HStack(alignment: .top, spacing: 10) {
            AppIconView(app: app, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(content.sender)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if group.notifications.count > 1 {
                        Text("\(group.notifications.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.2)))
                    }
                    Spacer(minLength: 8)
                    Text("\(app.name) · \(group.latest.date.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.45))
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
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
        .help(isExpanded ? "Close" : "Open the messages and reply")
    }

    private func message(_ notification: AppNotification) -> some View {
        let detail = service.content(for: notification).detail
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(detail.isEmpty ? "—" : detail)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(notification.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.08)))
    }

    /// For apps that cannot be answered from here (mail, system notices).
    private var openButton: some View {
        Button {
            service.catalog.open(group.latest.appIdentifier)
        } label: {
            Label("Open \(app.name)", systemImage: "arrow.up.forward.app")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
