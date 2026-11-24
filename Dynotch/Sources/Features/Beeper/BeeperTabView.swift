import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The reply field of a Beeper chat (spec BP-7, BP-9, BP-10): a quoted message, one file, emoji,
/// emoticons; Enter sends, only then.
struct BeeperComposer: View {
    var service: BeeperService
    let chat: BeeperChatInfo
    @Binding var replyTo: BeeperFullMessage?
    @Binding var editing: BeeperFullMessage?

    @State private var text = ""
    @State private var file: URL?
    @State private var isSending = false
    @FocusState private var isFocused: Bool
    @Environment(\.pinNotch) private var pinNotch

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let replyTo { chip(symbol: "arrowshape.turn.up.left.fill", text: replyTo.text ?? "Attachment") { self.replyTo = nil } }
            if let editing { chip(symbol: "pencil", text: "Editing: " + (editing.text ?? "")) { self.editing = nil; text = "" } }
            if let file { chip(symbol: "paperclip", text: file.lastPathComponent) { self.file = nil } }
            HStack(spacing: 8) {
                Button(action: chooseFile) {
                    Image(systemName: "plus.circle.fill").font(.notch(size: 18)).foregroundStyle(Color.white.level(0.7))
                }
                .buttonStyle(.notch)
                .help("Attach a file")
                .accessibilityLabel("Attach a file")
                TextField(editing == nil ? "Message \(chat.name)" : "Edit message", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.notch(size: 13))
                    .lineLimit(1...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: AppleStyle.corner(16), style: .continuous).fill(Color.white.level(0.1)))
                    .focused($isFocused)
                    .onSubmit(send)
                    .onChange(of: isFocused) { _, focused in if focused {
                        pinNotch()
                        // Read in Beeper only once the reply field is clicked (spec UM-3b).
                        service.markRead(chat.id)
                    } }
                    .onChange(of: text) { _, typed in
                        let replaced = Emoticons.replace(in: typed, includingLast: false)
                        if replaced != typed { text = replaced }
                    }
                EmojiButton(text: $text, size: 16)
                Button(action: send) {
                    Image(systemName: isSending ? "hourglass" : "arrow.up.circle.fill")
                        .font(.notch(size: 22))
                        .foregroundStyle(BeeperStyle.blue)
                }
                .buttonStyle(.notch)
                .disabled(isSending || (text.trimmingCharacters(in: .whitespaces).isEmpty && file == nil))
            }
            if let error = service.actionError {
                Text(error).font(.notch(size: 10)).foregroundStyle(Color.red).lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .dropDestination(for: URL.self) { urls, _ in
            file = urls.first
            return true
        }
        .onChange(of: editing?.id) { _, _ in
            if let editing { text = editing.text ?? ""; isFocused = true }
        }
        .onChange(of: replyTo?.id) { _, line in if line != nil { isFocused = true } }
    }

    private func chip(symbol: String, text: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.notch(size: 9)).foregroundStyle(BeeperStyle.blue)
            Text(text).font(.notch(size: 11)).foregroundStyle(Color.white.level(0.65)).lineLimit(1)
            Spacer(minLength: 4)
            Button(action: remove) {
                Image(systemName: "xmark").font(.notch(size: 9, weight: .semibold)).foregroundStyle(Color.white.level(0.5))
            }
            .buttonStyle(.notch)
        }
        .padding(.horizontal, 8)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        NSApp.activate()
        if panel.runModal() == .OK { file = panel.url }
    }

    /// Only Enter or the button sends (spec BP-10).
    private func send() {
        let message = Emoticons.replace(in: text.trimmingCharacters(in: .whitespacesAndNewlines), includingLast: true)
        guard !isSending, !message.isEmpty || file != nil else { return }
        if let editing {
            service.edit(editing.id, in: chat.id, text: message)
            self.editing = nil
            text = ""
            return
        }
        isSending = true
        let quoted = replyTo?.id
        let attached = file
        Task {
            if await service.send(message, to: chat.id, replyTo: quoted, file: attached) {
                text = ""
                file = nil
                replyTo = nil
            }
            isSending = false
        }
    }
}

/// The Beeper tab (spec BP-1): the chat list beside the conversation, Beeper's look.
struct BeeperTabView: View {
    /// The chat list grows with a resized module (spec RS-5).
    @State private var width: CGFloat = 0
    var service: BeeperService

    var body: some View {
        Group {
            switch service.state {
            case .noToken:
                note("Add a Beeper Desktop API token in Settings › Notifications.", symbol: "key")
            case .notRunning:
                EmptyStateView(
                    symbol: "bolt.horizontal.circle", text: "Beeper Desktop is not running, or its API is off.",
                    actionTitle: "Open Beeper", action: Self.openBeeper
                )
            case .failed(let message):
                note(message, symbol: "exclamationmark.triangle")
            case .idle, .ready:
                content
            }
        }
        .onAppear {
            service.refresh()
            if service.selectedChatID == nil, let first = service.sortedChats.first { service.open(first.id) }
        }
        .onDisappear { service.stopReading() }
    }

    /// With the list open: the chats beside the conversation; closed: the unread chats as cards,
    /// like the All tab (spec BP-1c). The two slide into each other.
    private var content: some View {
        ZStack {
            if service.showsChatList {
                conversations
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            } else {
                unread
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(Motion.quick, value: service.showsChatList)
        .readWidth($width)
    }

    private var conversations: some View {
        HStack(spacing: 0) {
            BeeperChatList(service: service)
                .frame(width: BeeperStyle.listWidth(for: width))
            Divider().overlay(Color.white.level(0.08))
            VStack(spacing: 0) {
                header
                if let chat = service.selectedChat {
                    BeeperConversation(service: service, chat: chat)
                        .id(chat.id)
                } else {
                    note("Choose a chat", symbol: "bubble.left.and.bubble.right")
                }
            }
        }
    }

    private var unread: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                listToggle
                Text("Unread").font(.notch(size: 13, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            if service.unreadChats.isEmpty {
                note("No unread chats", symbol: "checkmark.bubble")
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 6) {
                        BeeperUnreadCards(beeper: service) { chat in
                            // A card's arrow opens the chat with the list.
                            service.showsChatList = true
                            service.open(chat.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.never)
            }
        }
    }

    private var listToggle: some View {
        Button {
            service.showsChatList.toggle()
        } label: {
            Image(systemName: "sidebar.left").foregroundStyle(Color.white.level(service.showsChatList ? 0.9 : 0.55))
        }
        .buttonStyle(.notch)
        .help(service.showsChatList ? "Hide the chat list" : "Show the chats")
        .accessibilityLabel(service.showsChatList ? "Hide the chat list" : "Show the chats")
    }

    private var header: some View {
        HStack(spacing: 8) {
            listToggle
            if let chat = service.selectedChat {
                BeeperAvatar(image: service.avatar(chat.pictureURL), name: chat.name, network: chat.network, size: 24)
                Text(chat.name).font(.notch(size: 13, weight: .semibold)).lineLimit(1)
                Spacer()
                if chat.unread > 0 {
                    // Read in Beeper without replying (spec BP-20).
                    Button {
                        service.markRead(chat.id)
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .buttonStyle(.notch)
                    .help("Mark as read")
                    .accessibilityLabel("Mark as read")
                }
                BeeperReminderMenu(service: service, chat: chat)
                Button {
                    service.openInBeeper(chat.id)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.notch)
                .help("Open in Beeper")
                .accessibilityLabel("Open in Beeper")
            } else {
                Spacer()
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 34)
    }

    private func note(_ text: String, symbol: String) -> some View {
        EmptyStateView(symbol: symbol, text: text)
    }

    static func openBeeper() {
        let identifiers = ["com.automattic.beeper.desktop", "com.beeper.beeper-desktop"]
        let found = identifiers.lazy.compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        guard let url = found.first else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }
}

/// The chat's reminder (spec BP-6).
struct BeeperReminderMenu: View {
    var service: BeeperService
    let chat: BeeperChatInfo
    @State private var cancelOnReply = true

    var body: some View {
        Menu {
            Button("In 1 hour") { remind(Date().addingTimeInterval(3600)) }
            Button("This evening (18:00)") { remind(at: 18, dayOffset: 0) }
            Button("Tomorrow 9:00") { remind(at: 9, dayOffset: 1) }
            Button("Next week") { remind(at: 9, dayOffset: 7) }
            Divider()
            Toggle("Cancel if they reply", isOn: $cancelOnReply)
            if chat.reminder != nil {
                Divider()
                Button("Remove Reminder") { service.remind(chat.id, at: nil, cancelOnReply: false) }
            }
        } label: {
            Image(systemName: chat.reminder == nil ? "bell" : "bell.fill")
        }
        .menuStyle(.button)
        .buttonStyle(.notch)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Remind me about this chat")
        .accessibilityLabel("Remind me about this chat")
    }

    private func remind(at hour: Int, dayOffset: Int) {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
        remind(calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? Date().addingTimeInterval(3600))
    }

    private func remind(_ date: Date) {
        service.remind(chat.id, at: date, cancelOnReply: cancelOnReply)
    }
}
