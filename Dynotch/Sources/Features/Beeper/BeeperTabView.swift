import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The reply field of a Beeper chat (spec BP-7, BP-9, BP-10): a quoted message, one file, emoji,
/// emoticons; Enter sends, only then.
struct BeeperComposer: View {
    @ObservedObject var service: BeeperService
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
                    Image(systemName: "plus.circle.fill").font(.system(size: 18)).foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Attach a file")
                .accessibilityLabel("Attach a file")
                TextField(editing == nil ? "Message \(chat.name)" : "Edit message", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.1)))
                    .focused($isFocused)
                    .onSubmit(send)
                    .onChange(of: isFocused) { _, focused in if focused { pinNotch() } }
                    .onChange(of: text) { _, typed in
                        let replaced = Emoticons.replace(in: typed, includingLast: false)
                        if replaced != typed { text = replaced }
                    }
                EmojiButton(text: $text, size: 16)
                Button(action: send) {
                    Image(systemName: isSending ? "hourglass" : "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(BeeperStyle.blue)
                }
                .buttonStyle(.plain)
                .disabled(isSending || (text.trimmingCharacters(in: .whitespaces).isEmpty && file == nil))
            }
            if let error = service.actionError {
                Text(error).font(.system(size: 10)).foregroundStyle(Color(red: 1, green: 0.45, blue: 0.4)).lineLimit(1)
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
            Image(systemName: symbol).font(.system(size: 9)).foregroundStyle(BeeperStyle.blue)
            Text(text).font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.65)).lineLimit(1)
            Spacer(minLength: 4)
            Button(action: remove) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
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
    @ObservedObject var service: BeeperService

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

    private var content: some View {
        HStack(spacing: 0) {
            if service.showsChatList {
                BeeperChatList(service: service)
                    .frame(width: BeeperStyle.listWidth(for: width))
                Divider().overlay(Color.white.opacity(0.08))
            }
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
        .readWidth($width)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(Motion.quick) { service.showsChatList.toggle() }
            } label: {
                Image(systemName: "sidebar.left").foregroundStyle(Color.white.opacity(service.showsChatList ? 0.9 : 0.55))
            }
            .buttonStyle(.plain)
            .help(service.showsChatList ? "Hide the chat list" : "Show the chat list")
            if !service.showsChatList { chatPicker }
            if let chat = service.selectedChat {
                if service.showsChatList {
                    BeeperAvatar(image: service.avatar(chat.pictureURL), name: chat.name, network: chat.network, size: 24)
                    Text(chat.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                }
                Spacer()
                BeeperReminderMenu(service: service, chat: chat)
                Button {
                    service.openInBeeper(chat.id)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.plain)
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

    /// Without the list: the chats in a menu, unread first (spec BP-1b).
    private var chatPicker: some View {
        Menu {
            ForEach(service.sortedChats) { chat in
                Button(chat.unread > 0 ? "\(chat.name) (\(chat.unread))" : chat.name) { service.open(chat.id) }
            }
        } label: {
            HStack(spacing: 6) {
                if let chat = service.selectedChat {
                    BeeperAvatar(image: service.avatar(chat.pictureURL), name: chat.name, network: chat.network, size: 22)
                    Text(chat.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                }
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                if service.unreadTotal > 0 {
                    Text("\(service.unreadTotal)").font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5).background(Capsule().fill(BeeperStyle.blue))
                }
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
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
    @ObservedObject var service: BeeperService
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
        .buttonStyle(.plain)
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
