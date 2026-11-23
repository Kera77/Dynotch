import SwiftUI

/// An unread Beeper chat as a notification card in the Chats tab (spec UM-9): closed it shows the
/// newest message; a click opens the unread messages, each answerable on its own, and a reply
/// field that sends through Beeper.
struct BeeperUnreadCard: View {
    @ObservedObject var beeper: BeeperService
    let chat: BeeperChatInfo
    let isExpanded: Bool
    let toggle: () -> Void
    let openInTab: () -> Void

    @State private var text = ""
    @State private var quote: BeeperFullMessage?
    @State private var isSending = false
    @State private var hovered: String?
    @FocusState private var isFocused: Bool
    @Environment(\.pinNotch) private var pinNotch

    /// The unread messages from the others, the newest last.
    private var unread: [BeeperFullMessage] {
        let others = (beeper.messages[chat.id] ?? []).filter { !$0.mine && $0.isDeleted != true }
        return Array(others.suffix(max(chat.unread, 1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
                .contentShape(Rectangle())
                .onTapGesture(perform: toggle)
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(unread) { line($0) }
                }
                .padding(.leading, 36)
                field
                    .padding(.leading, 36)
                    .padding(.bottom, 4)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(10), style: .continuous)
            .fill(Color.white.level(isExpanded ? 0.1 : 0.07)))
        .onChange(of: isExpanded) { _, open in
            if open { beeper.loadMessages(chat.id) }
        }
        .onAppear {
            if isExpanded { beeper.loadMessages(chat.id) }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            BeeperAvatar(image: beeper.avatar(chat.pictureURL), name: chat.name, network: chat.network, size: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(chat.name)
                        .font(.notch(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(chat.unread)")
                        .font(.notch(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(BeeperStyle.blue))
                    Spacer(minLength: 8)
                    Text(subtitle)
                        .font(.notch(size: 10))
                        .foregroundStyle(Color.white.level(0.45))
                        .lineLimit(1)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.notch(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.level(0.45))
                    NotificationHeaderButton(symbol: "arrow.up.forward.square", help: "Open in the Beeper tab", action: openInTab)
                }
                if !isExpanded, let preview = chat.preview?.text, !preview.isEmpty {
                    Text(preview)
                        .font(.notch(size: 12))
                        .foregroundStyle(Color.white.level(0.8))
                        .lineLimit(2)
                }
            }
        }
        .help(isExpanded ? "Close" : "Open the messages and reply")
    }

    private var subtitle: String {
        let network = chat.network ?? "Beeper"
        let time = chat.lastActivity.flatMap(BeeperAPI.date(from:)).map { BeeperStyle.time($0) } ?? ""
        return time.isEmpty ? network : "\(network) · \(time)"
    }

    /// One message; hovering shows its own reply button (spec UM-9).
    private func line(_ message: BeeperFullMessage) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                if chat.isGroup, let sender = message.senderName {
                    Text(sender).font(.notch(size: 10, weight: .semibold)).foregroundStyle(Color.white.level(0.55))
                }
                Text(Self.text(of: message))
                    .font(.notch(size: 12))
                    .foregroundStyle(Color.white.level(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                quote = message
                isFocused = true
            } label: {
                Image(systemName: "arrowshape.turn.up.left.fill").font(.notch(size: 10))
            }
            .buttonStyle(.notch)
            .foregroundStyle(Color.white.level(0.7))
            .opacity(hovered == message.id || quote?.id == message.id ? 1 : 0)
            .help("Reply to this message")
            .accessibilityLabel("Reply to this message")
            Text(message.date.map { $0.formatted(date: .omitted, time: .shortened) } ?? "")
                .font(.notch(size: 10))
                .monospacedDigit()
                .foregroundStyle(Color.white.level(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: AppleStyle.corner(9), style: .continuous)
                .fill(Color.white.level(quote?.id == message.id ? 0.16 : 0.08))
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 ? message.id : (hovered == message.id ? nil : hovered) }
    }

    static func text(of message: BeeperFullMessage) -> String {
        if let text = message.text, !text.isEmpty { return text }
        return message.attachments?.isEmpty == false ? "Attachment" : "—"
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let quote {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill").font(.notch(size: 9))
                    Text(Self.text(of: quote)).font(.notch(size: 11)).lineLimit(1)
                    Spacer(minLength: 4)
                    Button { self.quote = nil } label: { Image(systemName: "xmark").font(.notch(size: 9, weight: .bold)) }
                        .buttonStyle(.notch)
                        .accessibilityLabel("Cancel the reply")
                }
                .foregroundStyle(Color.white.level(0.6))
                .padding(.horizontal, 4)
            }
            HStack(spacing: 8) {
                TextField("Reply…", text: $text)
                    .textFieldStyle(.plain)
                    .font(.notch(size: 12))
                    .foregroundStyle(.white)
                    .focused($isFocused)
                    .onSubmit(send)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).fill(Color.white.level(0.1)))
                    .onChange(of: isFocused) { _, focused in if focused {
                        pinNotch()
                        beeper.markRead(chat.id)
                    } }
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.notch(size: 20))
                }
                .buttonStyle(.notch)
                .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.level(0.3) : Theme.blue)
                .disabled(isSending || text.trimmingCharacters(in: .whitespaces).isEmpty)
                .help("Send")
                .accessibilityLabel("Send")
            }
        }
    }

    private func send() {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isSending else { return }
        isSending = true
        let replyTo = quote?.id
        Task {
            let sent = await beeper.send(message, to: chat.id, replyTo: replyTo)
            isSending = false
            if sent {
                text = ""
                quote = nil
            }
        }
    }
}

/// The unread Beeper chats as cards, one open at a time (spec UM-9).
struct BeeperUnreadCards: View {
    @ObservedObject var beeper: BeeperService
    /// One highlighted network's chats (spec BP-15); nil: the ones Beeper stands for together.
    var network: String?
    let open: (BeeperChatInfo) -> Void

    @State private var expanded: String?

    var body: some View {
        let chats = Array((network.map(beeper.unreadChats(network:)) ?? beeper.unreadChats).prefix(12))
        ForEach(chats) { chat in
            BeeperUnreadCard(
                beeper: beeper,
                chat: chat,
                isExpanded: expanded == chat.id || chats.count == 1,
                toggle: { withAnimation(Motion.quick) { expanded = expanded == chat.id ? nil : chat.id } },
                openInTab: { open(chat) }
            )
        }
    }
}

/// A highlighted Beeper network's tab: its unread chats as cards with their reply field (spec BP-15).
struct BeeperNetworkTab: View {
    @ObservedObject var beeper: BeeperService
    let network: String
    let open: (BeeperChatInfo) -> Void

    var body: some View {
        if beeper.state != .ready {
            EmptyStateView(symbol: "bubble.left.and.bubble.right", text: "Beeper is not connected.")
        } else if beeper.unreadChats(network: network).isEmpty {
            EmptyStateView(symbol: "checkmark.bubble", text: "No unread \(network) chats.")
        } else {
            ScrollView(.vertical) {
                VStack(spacing: 6) {
                    BeeperUnreadCards(beeper: beeper, network: network, open: open)
                }
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.never)
        }
    }
}
