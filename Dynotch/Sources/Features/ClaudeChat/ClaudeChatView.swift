import SwiftUI

/// Claude in the notch (spec CC-1…CC-3): the chats on the left, the conversation on the right.
struct ClaudeChatFeatureView: View {
    @ObservedObject var service: ClaudeChatService
    let isActive: Bool

    private static let sidebarWidth: CGFloat = 160

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Self.sidebarWidth)
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)
            conversation
                .padding(.leading, 12)
        }
        .padding(.top, 4)
        .onAppear { service.isVisible = isActive }
        .onChange(of: isActive) { _, active in
            service.isVisible = active
        }
    }

    // MARK: - Chats

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                service.newChat()
            } label: {
                Label("New chat", systemImage: "square.and.pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(service.selectedID == nil ? 0.2 : 0.1))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            ScrollView(.vertical) {
                VStack(spacing: 2) {
                    ForEach(service.chats) { chat in
                        ChatRow(chat: chat, isSelected: chat.id == service.selectedID, isWorking: chat.id == service.workingID) {
                            service.select(chat.id)
                        } delete: {
                            service.delete(chat.id)
                        }
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(.trailing, 10)
    }

    // MARK: - Conversation

    private var conversation: some View {
        VStack(spacing: 8) {
            if let chat = service.selected, !chat.messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(chat.messages) { message in
                                let isLast = message.id == chat.messages.last?.id
                                ChatBubble(message: message, isWriting: service.workingID == chat.id && isLast)
                                    .id(message.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.never)
                    .onChange(of: chat.messages.last?.text) { _, _ in
                        if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                    .onAppear {
                        if let last = chat.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    BrandGlyphView(glyph: .claude, size: 26)
                    Text("Ask Claude anything")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            inputRow
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField(service.selected == nil ? "New chat — Enter sends" : "Reply — Enter sends", text: $service.draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.1)))
                .onSubmit { service.send() }
            Button {
                if service.isWorking {
                    service.stop()
                } else {
                    service.send()
                }
            } label: {
                Image(systemName: service.isWorking ? "stop.fill" : "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ClaudeUsageView.blue))
            }
            .buttonStyle(.plain)
            .disabled(!service.isWorking && service.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help(service.isWorking ? "Stop" : "Send")
        }
    }
}

private struct ChatRow: View {
    let chat: ClaudeChat
    let isSelected: Bool
    let isWorking: Bool
    let select: () -> Void
    let delete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Text(chat.title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.75))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isWorking {
                ProgressView().controlSize(.mini)
            } else if isHovered {
                Button(action: delete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete this chat")
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(isSelected ? 0.16 : 0)))
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .onHover { isHovered = $0 }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let isWriting: Bool

    var body: some View {
        switch message.role {
        case .user:
            Text(message.text)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.14)))
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .assistant:
            HStack(alignment: .top, spacing: 8) {
                BrandGlyphView(glyph: .claude, size: 14)
                    .padding(.top, 2)
                if message.text.isEmpty, isWriting {
                    WorkingDots()
                        .frame(height: 16)
                } else {
                    Text(Self.formatted(message.text))
                        .font(.system(size: 13))
                        .foregroundStyle(message.isError ? Color(red: 1, green: 0.5, blue: 0.45) : Color.white.opacity(0.92))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Bold, italic, code and links; line breaks stay as written.
    static func formatted(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

/// Three dots lighting up in turn: Claude is working (spec CC-4).
struct WorkingDots: View {
    var color: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { context in
            let step = context.date.timeIntervalSinceReferenceDate * 2.2
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .opacity(0.3 + 0.7 * max(0, sin(step - Double(index) * 0.9)))
                }
            }
        }
    }
}
