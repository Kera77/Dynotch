import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// One chat's messages and the reply field (spec BP-1…BP-10).
struct BeeperConversation: View {
    @ObservedObject var service: BeeperService
    let chat: BeeperChatInfo

    @State private var replyTo: BeeperFullMessage?
    @State private var hovered: String?
    @State private var editing: BeeperFullMessage?

    static let quickReactions = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    private var messages: [BeeperFullMessage] { service.messages[chat.id] ?? [] }

    var body: some View {
        VStack(spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            if showsDay(at: index) { daySeparator(message.date) }
                            bubbleRow(message, showsSender: chat.isGroup && !message.mine && showsSender(at: index))
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .scrollIndicators(.never)
                .onAppear { scrollToEnd(proxy) }
                .onChange(of: messages.last?.id) { _, _ in scrollToEnd(proxy) }
            }
            BeeperComposer(service: service, chat: chat, replyTo: $replyTo, editing: $editing)
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
    }

    private func showsDay(at index: Int) -> Bool {
        guard let date = messages[index].date else { return false }
        guard index > 0, let previous = messages[index - 1].date else { return true }
        return !Calendar.current.isDate(date, inSameDayAs: previous)
    }

    private func showsSender(at index: Int) -> Bool {
        index == 0 || messages[index - 1].senderID != messages[index].senderID
    }

    private func daySeparator(_ date: Date?) -> some View {
        let text: String = {
            guard let date else { return "" }
            if Calendar.current.isDateInToday(date) { return "Today" }
            if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
            return date.formatted(date: .abbreviated, time: .omitted)
        }()
        return Text(text)
            .font(.notch(size: 10, weight: .semibold))
            .foregroundStyle(Color.white.level(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    private func bubbleRow(_ message: BeeperFullMessage, showsSender: Bool) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if message.mine { Spacer(minLength: 60) }
            if message.mine { actions(message) }
            VStack(alignment: message.mine ? .trailing : .leading, spacing: 2) {
                if showsSender, let sender = message.senderName {
                    Text(sender)
                        .font(.notch(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.level(0.55))
                }
                bubble(message)
                    // A click on a message answers it (spec BP-4b).
                    .onTapGesture { replyTo = message }
                reactions(message)
                if service.canUndo(message) {
                    Button("Undo") { service.undo(message.id, in: chat.id) }
                        .buttonStyle(.notch)
                        .font(.notch(size: 10, weight: .semibold))
                        .foregroundStyle(BeeperStyle.blue)
                }
            }
            if !message.mine { actions(message) }
            if !message.mine { Spacer(minLength: 60) }
        }
        .onHover { inside in
            if inside { hovered = message.id } else if hovered == message.id { hovered = nil }
        }
        .contextMenu { menu(message) }
    }

    /// Reply and react beside the message, in a place of fixed size so hovering does not move
    /// anything (spec BP-4b).
    private func actions(_ message: BeeperFullMessage) -> some View {
        HStack(spacing: 4) {
            Button {
                replyTo = message
            } label: {
                Image(systemName: "arrowshape.turn.up.left.fill").font(.notch(size: 10))
            }
            .buttonStyle(.notch)
            .help("Reply")
            .accessibilityLabel("Reply")
            BeeperReactionButton { emoji in service.react(emoji, to: message, in: chat.id) }
        }
        .foregroundStyle(Color.white.level(0.7))
        .frame(width: 44)
        .opacity(hovered == message.id ? 1 : 0)
    }

    private func bubble(_ message: BeeperFullMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let linked = message.linkedMessageID, let quoted = messages.first(where: { $0.id == linked }) {
                HStack(spacing: 6) {
                    Rectangle().fill(Color.white.level(0.6)).frame(width: 2)
                    Text(quoted.text ?? "Attachment").font(.notch(size: 11)).lineLimit(2).opacity(0.75)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array((message.attachments ?? []).enumerated()), id: \.offset) { _, attachment in
                BeeperAttachmentView(service: service, attachment: attachment)
            }
            if let text = message.text, !text.isEmpty {
                Text(text)
                    .font(.notch(size: 13))
                    .textSelection(.enabled)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(14), style: .continuous)
            .fill(message.mine ? BeeperStyle.blue : BeeperStyle.incoming))
    }

    @ViewBuilder private func reactions(_ message: BeeperFullMessage) -> some View {
        let keys = (message.reactions ?? []).compactMap(\.reactionKey)
        if !keys.isEmpty {
            HStack(spacing: 4) {
                ForEach(Array(Set(keys)).sorted(), id: \.self) { key in
                    Button {
                        service.react(key, to: message, in: chat.id)
                    } label: {
                        Text("\(key) \(keys.filter { $0 == key }.count)")
                            .font(.notch(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.level(0.14)))
                    }
                    .buttonStyle(.notch)
                }
            }
        }
    }

    @ViewBuilder private func menu(_ message: BeeperFullMessage) -> some View {
        Button("Reply") { replyTo = message }
        Button("Open in Beeper") { service.openInBeeper(chat.id, messageID: message.id) }
        if let text = message.text {
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
        if message.mine {
            Divider()
            Button("Edit") { editing = message }
            Button("Delete", role: .destructive) { service.delete(message.id, in: chat.id) }
        }
    }
}

/// Images and GIFs small in the bubble, video and voice with their length, files with name and
/// size (spec BP-8). A click opens it.
struct BeeperAttachmentView: View {
    @ObservedObject var service: BeeperService
    let attachment: BeeperAttachment

    var body: some View {
        let address = attachment.type == "img" ? (attachment.srcURL ?? attachment.id) : (attachment.posterImg ?? nil)
        Button(action: open) {
            if let image = service.avatar(address) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous))
                    .overlay(alignment: .bottomLeading) { duration }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: symbol).font(.notch(size: 16))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(attachment.fileName ?? title).font(.notch(size: 12, weight: .medium)).lineLimit(1)
                        Text(detail).font(.notch(size: 10)).opacity(0.7)
                    }
                }
            }
        }
        .buttonStyle(.notch)
        if let transcription = attachment.transcription, !transcription.isEmpty {
            Text(transcription).font(.notch(size: 11)).italic().opacity(0.8)
        }
    }

    @ViewBuilder private var duration: some View {
        if let seconds = attachment.duration {
            Text(Self.length(seconds))
                .font(.notch(size: 10, weight: .semibold))
                .padding(4)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .padding(4)
        }
    }

    private var symbol: String {
        if attachment.isVoiceNote == true { return "waveform" }
        switch attachment.type {
        case "video": return "film"
        case "audio": return "music.note"
        case "img": return "photo"
        default: return "doc.fill"
        }
    }

    private var title: String {
        attachment.isVoiceNote == true ? "Voice message" : (attachment.type == "video" ? "Video" : "File")
    }

    private var detail: String {
        var parts: [String] = []
        if let seconds = attachment.duration { parts.append(Self.length(seconds)) }
        if let size = attachment.fileSize { parts.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)) }
        return parts.joined(separator: " · ")
    }

    static func length(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func open() {
        guard let address = attachment.srcURL ?? attachment.id else { return }
        Task {
            guard let url = try? await BeeperAPI.download(address) else { return }
            if url.isFileURL { TrayQuickLook.shared.toggle(url) } else { NSWorkspace.shared.open(url) }
        }
    }
}

/// Hover: the quick reactions; click: every emoji (spec BP-4b).
struct BeeperReactionButton: View {
    let react: (String) -> Void

    private enum Panel: Identifiable {
        case quick
        case all

        var id: Int { self == .quick ? 0 : 1 }
    }

    @State private var panel: Panel?
    @State private var hover = HoverIntent()
    @Environment(\.pinNotch) private var pinNotch

    var body: some View {
        Button {
            panel = .all
            hover.openedByHover = false
            pinNotch()
        } label: {
            Image(systemName: "face.smiling").font(.notch(size: 11))
        }
        .buttonStyle(.notch)
        .help("React")
        .accessibilityLabel("React")
        .onHover { inside in
            hover.overButton = inside
            if inside, panel == nil {
                panel = .quick
                hover.openedByHover = true
            }
            closeIfLeft()
        }
        .popover(item: $panel, arrowEdge: .bottom) { shown in
            popoverContent(shown)
                .onHover { inside in
                    hover.overPopover = inside
                    closeIfLeft()
                }
        }
    }

    private func closeIfLeft() {
        DispatchQueue.main.asyncAfter(deadline: .now() + HoverIntent.grace) {
            if hover.shouldClose { panel = nil }
        }
    }

    @ViewBuilder private func popoverContent(_ shown: Panel) -> some View {
        switch shown {
        case .quick:
            HStack(spacing: 4) {
                ForEach(BeeperConversation.quickReactions, id: \.self) { emoji in
                    Button(emoji) {
                        react(emoji)
                        panel = nil
                    }
                    .buttonStyle(.notch)
                    .font(.notch(size: 18))
                }
                Button {
                    // Every emoji, staying until a click (spec E-18b).
                    hover.openedByHover = false
                    panel = .all
                } label: {
                    Image(systemName: "plus.circle").font(.notch(size: 14))
                }
                .buttonStyle(.notch)
            }
            .padding(8)
        case .all:
            EmojiGrid { emoji in
                react(emoji)
                EmojiGrid.remember(emoji)
                panel = nil
            }
        }
    }
}
