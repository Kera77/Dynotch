import SwiftUI

/// The Teams tab: the web Teams' unread chats, a card with the last messages and a reply field
/// (spec MT-3, MT-4); the Teams notifications when the page can't be read.
struct TeamsTabView: View {
    var teams: TeamsService
    var service: NotificationService
    var isActive = false

    @State private var openChat: String?

    var body: some View {
        if teams.state == .reading, let snapshot = teams.snapshot {
            list(snapshot)
        } else {
            NotificationsFeatureView(
                service: service, isActive: isActive,
                include: { TeamsTabView.isTeams($0) },
                leading: AnyView(hint)
            )
        }
    }

    nonisolated static func isTeams(_ notification: AppNotification) -> Bool {
        TeamsPage.isTeamsHost(notification.site) || notification.appIdentifier.lowercased().contains("teams")
    }

    private var hint: some View {
        Text(hintText)
            .font(.notch(size: 11))
            .foregroundStyle(Color.white.level(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
    }

    private var hintText: String {
        switch teams.state {
        case .off: "Reading Teams is off (Settings › Chats › Teams)."
        case .noAccess: "Teams needs Accessibility access (Settings › Chats)."
        case .notFound, .reading: "Open Teams in a browser window of its own to read and answer chats here."
        case .backgroundTab: "Teams is in a background tab: Settings › Chats › Teams can move it to a window of its own."
        }
    }

    private func list(_ snapshot: TeamsSnapshot) -> some View {
        let unread = snapshot.unread
        let shown = unread.isEmpty ? Array(snapshot.chats.prefix(5)) : unread
        return ScrollView(.vertical) {
            VStack(spacing: 6) {
                if unread.isEmpty {
                    Text("No unread Teams chats")
                        .font(.notch(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.level(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                ForEach(shown) { chat in
                    TeamsChatCard(teams: teams, chat: chat, isOpen: openChat == chat.id, isRecent: unread.isEmpty) {
                        withAnimation(Motion.quick) { openChat = openChat == chat.id ? nil : chat.id }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.never)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// One chat: name, last message, time; open, its last messages and a reply field (spec MT-4).
private struct TeamsChatCard: View {
    var teams: TeamsService
    let chat: TeamsChat
    let isOpen: Bool
    let isRecent: Bool
    let toggle: () -> Void

    @State private var messages: [TeamsMessage]?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: toggle) { header }
                .buttonStyle(.notch)
            if isOpen { content }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Theme.fill))
        .opacity(isRecent && !isOpen ? 0.6 : 1)
        .onChange(of: isOpen) { _, open in if open { load() } }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if chat.isMention {
                Text("@")
                    .font(.notch(size: 12, weight: .bold))
                    .foregroundStyle(Theme.red)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.name)
                    .font(.notch(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !isOpen, !chat.preview.isEmpty {
                    Text(chat.preview)
                        .font(.notch(size: 12))
                        .foregroundStyle(Color.white.level(0.7))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 6)
            Text(chat.time)
                .font(.notch(size: 10))
                .foregroundStyle(Color.white.level(0.5))
            if chat.isUnread {
                Circle().fill(Theme.blue).frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var content: some View {
        if let messages {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(messages.suffix(8).enumerated()), id: \.element.id) { index, message in
                    let shown = messages.suffix(8)
                    let previous = index > 0 ? shown[shown.index(shown.startIndex, offsetBy: index - 1)] : nil
                    TeamsMessageLine(message: message, showsSender: previous?.sender != message.sender)
                }
            }
        } else if isLoading {
            ProgressView().controlSize(.small).frame(maxWidth: .infinity)
        } else {
            Text("Couldn't open this chat in Teams.")
                .font(.notch(size: 11))
                .foregroundStyle(Color.white.level(0.5))
        }
        TeamsReplyField(teams: teams, chat: chat) { load() }
        Button("Open in Teams") { teams.openInBrowser(chat: chat.id) }
            .buttonStyle(.notch)
            .font(.notch(size: 11, weight: .semibold))
            .foregroundStyle(Theme.blue)
    }

    private func load() {
        isLoading = true
        Task {
            let read = await teams.openAndRead(chat.id)
            messages = read
            isLoading = false
        }
    }
}

private struct TeamsMessageLine: View {
    let message: TeamsMessage
    let showsSender: Bool

    var body: some View {
        VStack(alignment: message.isMine ? .trailing : .leading, spacing: 1) {
            if showsSender, let sender = message.sender {
                Text(sender)
                    .font(.notch(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.level(0.5))
            }
            Text(message.text)
                .font(.notch(size: 12))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .fill(message.isMine ? Theme.blue.opacity(0.45) : Color.white.level(0.12))
                )
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
    }
}

/// Enter sends the text into the chat in Teams (spec MT-4).
private struct TeamsReplyField: View {
    var teams: TeamsService
    let chat: TeamsChat
    let sent: () -> Void

    @State private var text = ""
    @State private var isSending = false
    @State private var failed = false
    @FocusState private var isFocused: Bool
    @Environment(\.pinNotch) private var pinNotch
    @Environment(\.takeKeyboard) private var takeKeyboard

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                TextField("Reply to \(chat.name)…", text: $text)
                    .textFieldStyle(.plain)
                    .font(.notch(size: 13))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Color.white.level(0.1)))
                    .focused($isFocused)
                    .onSubmit(send)
                    .disabled(isSending)
                    .onChange(of: isFocused) { _, focused in if focused { pinNotch() } }
                    .simultaneousGesture(TapGesture().onEnded { takeKeyboard() })
                Button(action: send) {
                    Group {
                        if isSending { ProgressView().controlSize(.small) } else { Image(systemName: "paperplane.fill") }
                    }
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous).fill(Theme.blue))
                }
                .buttonStyle(.notch)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
            }
            if failed {
                Text("Not sent: Teams didn't show it. Your text is kept.")
                    .font(.notch(size: 10))
                    .foregroundStyle(Theme.red)
            }
        }
    }

    private func send() {
        let reply = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty, !isSending else { return }
        isSending = true
        failed = false
        Task {
            let done = await teams.send(reply, to: chat.id)
            isSending = false
            if done {
                text = ""
                sent()
            } else {
                failed = true
            }
        }
    }
}
