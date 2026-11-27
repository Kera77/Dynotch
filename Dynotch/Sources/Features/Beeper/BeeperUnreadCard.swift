import SwiftUI

/// An unread Beeper chat as a notification card in the Chats tab (spec UM-9): closed it shows the
/// newest message; a click opens the unread messages, each answerable on its own, and a reply
/// field that sends through Beeper.
struct BeeperUnreadCard: View {
    var beeper: BeeperService
    let chat: BeeperChatInfo
    let isExpanded: Bool
    let toggle: () -> Void
    let openInTab: () -> Void
    /// Each change (from a badge's drop-down) focuses the reply field (spec B-10f).
    var focusRequest = 0

    @State private var text = ""
    @State private var quote: BeeperFullMessage?
    @State private var isSending = false
    @State private var hovered: String?
    @FocusState private var isFocused: Bool
    @Environment(\.pinNotch) private var pinNotch
    @Environment(\.takeKeyboard) private var takeKeyboard
    /// Focused by itself after a click on the card: read only once typing starts (spec E-27, UM-3b).
    @State private var focusedBySelf = false
    /// The first unread message when answering began: still shown after the chat got read (spec E-32).
    @State private var anchor: String?

    /// The unread messages from the others, the newest last; while the card is being answered,
    /// from the first of them on, my replies included (spec BP-21, E-32).
    private var unread: [BeeperFullMessage] {
        let all = (beeper.messages[chat.id] ?? []).filter { $0.isDeleted != true }
        let others = Array(all.filter { !$0.mine }.suffix(max(chat.unread, 1)))
        guard beeper.answeringChatID == chat.id, let first = anchor ?? others.first?.id,
              let start = all.firstIndex(where: { $0.id == first })
        else { return others }
        return Array(all[start...].suffix(8))
    }

    /// Clicked into or typed: read in Beeper, but the card stays with its messages until another
    /// card opens or the notch closes (spec UM-3b, E-32).
    private func engage() {
        if anchor == nil { anchor = unread.first?.id }
        beeper.answeringChatID = chat.id
        beeper.markRead(chat.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
                .contentShape(Rectangle())
                .onTapGesture {
                    // Opened by a click: the reply field takes typing at once (spec E-27).
                    if !isExpanded { focusReply() }
                    toggle()
                }
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(unread) { line($0) }
                }
                .animation(Motion.quick, value: unread.map(\.id))
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
            if focusRequest > 0 { focusReply() }
        }
        .onChange(of: focusRequest) { _, _ in focusReply() }
        .onChange(of: beeper.answeringChatID) { _, id in
            if id != chat.id { anchor = nil }
        }
    }

    /// Focused by itself: the panel takes the keyboard, then the field (spec E-27).
    private func focusReply() {
        focusedBySelf = true
        takeKeyboard()
        DispatchQueue.main.async { isFocused = true }
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
                    if chat.unread > 0 {
                        Text("\(chat.unread)")
                            .font(.notch(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(BeeperStyle.blue))
                    }
                    Spacer(minLength: 8)
                    Text(subtitle)
                        .font(.notch(size: 10))
                        .foregroundStyle(Color.white.level(0.45))
                        .lineLimit(1)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.notch(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.level(0.45))
                    // Read in Beeper without replying (spec BP-20).
                    NotificationHeaderButton(symbol: "checkmark", help: "Mark as read") { beeper.markRead(chat.id) }
                        .accessibilityLabel("Mark \(chat.name) as read")
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

    /// One message; hovering shows its own reply button (spec UM-9). The others' from the left,
    /// mine on the right (spec E-33).
    private func line(_ message: BeeperFullMessage) -> some View {
        MessageBubble(mine: message.mine, highlighted: quote?.id == message.id) {
            VStack(alignment: .leading, spacing: 1) {
                if !message.mine, chat.isGroup, let sender = message.senderName {
                    Text(sender).font(.notch(size: 10, weight: .semibold)).foregroundStyle(Color.white.level(0.55))
                }
                MessageBubbleText(text: Text(Self.text(of: message)), time: message.date, mine: message.mine)
            }
        } accessory: {
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
        }
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
                    .onChange(of: isFocused) { _, focused in
                        if focused {
                            pinNotch()
                            if !focusedBySelf { engage() }
                        } else {
                            focusedBySelf = false
                        }
                    }
                    .onChange(of: text) { _, typed in
                        if focusedBySelf, !typed.isEmpty {
                            focusedBySelf = false
                            engage()
                        }
                    }
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
        // Answered: the card stays open for the next message (spec BP-21).
        if anchor == nil { anchor = unread.first?.id }
        beeper.answeringChatID = chat.id
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
    var beeper: BeeperService
    /// One highlighted network's chats (spec BP-15); nil: the ones Beeper stands for together.
    var network: String?
    let open: (BeeperChatInfo) -> Void

    @State private var expanded: String?
    /// The chat opened from a badge's drop-down, and a count that focuses its field (spec B-10f).
    @State private var focusedChat: String?
    @State private var focusToken = 0

    private var chats: [BeeperChatInfo] {
        Array(beeper.cardChats(network: network).prefix(12))
    }

    var body: some View {
        let chats = chats
        ForEach(chats) { chat in
            BeeperUnreadCard(
                beeper: beeper,
                chat: chat,
                isExpanded: expanded == chat.id || chats.count == 1,
                toggle: { toggle(chat) },
                openInTab: { open(chat) },
                focusRequest: focusedChat == chat.id ? focusToken : 0
            )
        }
        .onAppear { openRequested() }
        .onChange(of: beeper.cardRequest) { _, _ in openRequested() }
    }

    /// Opening another card lets the answered one go (spec BP-21).
    private func toggle(_ chat: BeeperChatInfo) {
        let opens = expanded != chat.id
        if opens, beeper.answeringChatID != chat.id { beeper.answeringChatID = nil }
        withAnimation(Motion.quick) { expanded = opens ? chat.id : nil }
    }

    /// Opens the chat asked for from a badge's drop-down, its reply field ready (spec B-10f).
    private func openRequested() {
        guard let request = beeper.cardRequest, let chat = chats.first(where: { request.matches($0.name) }) else { return }
        DispatchQueue.main.async {
            beeper.cardRequest = nil
            if beeper.answeringChatID != chat.id { beeper.answeringChatID = nil }
            withAnimation(Motion.quick) { expanded = chat.id }
            focusedChat = chat.id
            focusToken += 1
        }
    }
}

/// A highlighted Beeper network's tab: its unread chats as cards with their reply field (spec BP-15).
struct BeeperNetworkTab: View {
    var beeper: BeeperService
    let network: String
    let open: (BeeperChatInfo) -> Void

    var body: some View {
        if beeper.state != .ready {
            EmptyStateView(symbol: "bubble.left.and.bubble.right", text: "Beeper is not connected.")
        } else if beeper.cardChats(network: network).isEmpty {
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

extension BeeperService {
    /// The unread chats as cards, with the one being answered kept even once it was read (spec BP-21).
    /// - Parameter network: a highlighted network's tab (spec BP-15); nil: the chats Beeper stands for together.
    func cardChats(network: String? = nil) -> [BeeperChatInfo] {
        var list = network.map(unreadChats(network:)) ?? unreadChats
        guard let id = answeringChatID, !list.contains(where: { $0.id == id }),
              let chat = chats.first(where: { $0.id == id })
        else { return list }
        let belongs = network.map { chat.network == $0 } ?? !highlightedNetworks.contains(chat.network ?? "")
        if belongs { list.insert(chat, at: 0) }
        return list
    }
}
