import SwiftUI

/// Claude in the notch (spec CC-1…CC-3): the chats on the left, the conversation on the right.
struct ClaudeChatFeatureView: View {
    @ObservedObject var service: ClaudeChatService
    let isActive: Bool

    var body: some View {
        ClaudeChatView(service: service)
            .padding(.top, 4)
            .onAppear { service.isVisible = isActive }
            // The panel's content is removed when it closes, without `isActive` changing first.
            .onDisappear { service.isVisible = false }
            .onChange(of: isActive) { _, active in
                service.isVisible = active
            }
    }
}

/// Content of the Claude menu bar panel (spec CC-8).
struct ClaudeChatMenuBarView: View {
    @ObservedObject var service: ClaudeChatService
    @ObservedObject var state: MenuBarPanelState

    var body: some View {
        ClaudeChatView(service: service)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .popoverChrome(arrowX: state.arrowX)
    }
}

/// The chat itself, shared by the notch and the menu bar panel.
struct ClaudeChatView: View {
    @ObservedObject var service: ClaudeChatService

    @State private var search = ""
    @FocusState private var isTyping: Bool

    private static let sidebarWidth: CGFloat = 160

    var body: some View {
        HStack(spacing: 0) {
            if service.showsSidebar {
                sidebar
                    .frame(width: Self.sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)
            }
            conversation
                .padding(.leading, service.showsSidebar ? 12 : 0)
        }
        .clipped()
        .onAppear {
            service.refreshCodeSessions()
            // Opened (also by its shortcut): ready to type (spec AI-4).
            DispatchQueue.main.async { isTyping = true }
        }
        .dropDestination(for: URL.self) { urls, _ in
            service.attachments += urls
            return true
        }
    }

    /// Opens and closes the list of chats (spec CC-7).
    private var sidebarToggle: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { service.showsSidebar.toggle() }
        } label: {
            SidebarGlyph()
                .foregroundStyle(Color.white.opacity(service.showsSidebar ? 0.9 : 0.65))
                .frame(width: 28, height: 26)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.1)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(service.showsSidebar ? "Hide the chats" : "Show the chats")
    }

    // MARK: - Chats

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                newChatButton
                sidebarToggle
            }
            TextField("Search", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.08)))
            ScrollView(.vertical) {
                VStack(spacing: 2) {
                    ForEach(service.listedChats(matching: search)) { chat in
                        ChatRow(
                            title: (chat.isPinned == true ? "📌 " : "") + chat.title, isSelected: chat.id == service.selectedID,
                            isWorking: chat.id == service.workingID,
                            select: { service.select(chat.id) },
                            delete: { service.delete(chat.id) }
                        )
                        .contextMenu {
                            Button(chat.isPinned == true ? "Unpin" : "Pin") { service.togglePin(chat.id) }
                            Button("Delete", role: .destructive) { service.delete(chat.id) }
                        }
                    }
                    if !service.codeSessions.isEmpty {
                        Text("FROM CLAUDE CODE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                        ForEach(service.codeSessions) { session in
                            ChatRow(title: session.title, isSelected: false, isWorking: false, select: { service.open(session) })
                        }
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(.trailing, 10)
    }

    private var newChatButton: some View {
        Button {
            service.newChat()
        } label: {
            Label("New chat", systemImage: "square.and.pencil")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
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
    }

    // MARK: - Conversation

    private var conversation: some View {
        VStack(spacing: 8) {
            AIChatHeader(service: service)
            if let chat = service.selected, !chat.messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(chat.messages) { message in
                                let isLast = message.id == chat.messages.last?.id
                                ChatBubble(message: message, isWriting: service.workingID == chat.id && isLast, provider: chat.service)
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
                    AIGlyph(provider: service.provider, size: 26)
                    Text("Ask \(service.provider.title) anything")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            AIContextBar(service: service)
            inputRow
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            // With the list hidden its button moves here.
            if !service.showsSidebar { sidebarToggle }
            TextField(service.selected == nil ? "New chat — Enter sends" : "Reply — Enter sends", text: $service.draft)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.1)))
                .focused($isTyping)
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
    let title: String
    let isSelected: Bool
    let isWorking: Bool
    let select: () -> Void
    /// nil: the row cannot be deleted (Claude Code's own sessions).
    var delete: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.75))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isWorking {
                ProgressView().controlSize(.mini)
            } else if isHovered, let delete {
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
    var provider = AIProvider.claude

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
                AIGlyph(provider: provider, size: 14)
                    .padding(.top, 2)
                if message.text.isEmpty, isWriting {
                    WorkingDots()
                        .frame(height: 16)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        AIMessageContent(text: message.text, isError: message.isError)
                        if !isWriting, !message.isError { AIAnswerActions(text: message.text) }
                    }
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

/// The sidebar button's mark: a rounded frame with a short bar at its left edge.
struct SidebarGlyph: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .stroke(lineWidth: 1.5)
            Capsule()
                .frame(width: 2, height: 6)
                .padding(.leading, 3.5)
        }
        .frame(width: 16, height: 12)
    }
}

/// Claude's mark or ChatGPT's symbol.
struct AIGlyph: View {
    let provider: AIProvider
    var size: CGFloat = 14

    var body: some View {
        switch provider {
        case .claude:
            BrandGlyphView(glyph: .claude, size: size)
        case .chatgpt:
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: size * 0.9, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
