import SwiftUI

/// A text field that answers a notification's chat (spec E-11): Enter or the button sends.
/// It can answer one line of the conversation (spec E-17), offers the emoji picker and turns
/// typed emoticons into emoji (spec E-18).
struct NotificationReplyField: View {
    let service: NotificationService
    /// The reply goes to this message's chat.
    let target: AppNotification
    /// The line answered; nil: the conversation as a whole.
    var quote: AppNotification?
    var cancelQuote: () -> Void = {}
    /// Focused as soon as it shows: the card was opened by a click (spec E-27).
    var focusesOnAppear = false
    /// Each change focuses the field (a click on the card's text, spec E-27).
    var focusRequest = 0
    /// After a reply went out, with its text.
    var sent: (String) -> Void = { _ in }

    @State private var text = ""
    @FocusState private var isFocused: Bool
    @Environment(\.pinNotch) private var pinNotch
    @Environment(\.takeKeyboard) private var takeKeyboard
    /// Focused by itself, not by a click: the chat counts as opened only once typing starts (spec E-27).
    @State private var focusedBySelf = false
    @State private var status: Status = .idle

    enum Status: Equatable {
        case idle
        case sending
        case sent(String)
        case failed(String)
    }

    private static var blue: Color { Theme.blue }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let quote { quoteChip(quote) }
            HStack(spacing: 8) {
                field
                emojiButton
                sendButton
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let note = statusNote {
                Text(note.text)
                    .font(.notch(size: 10))
                    .foregroundStyle(note.isError ? Color.red : Color.white.level(0.5))
                    .lineLimit(1)
                    .padding(.horizontal, 2)
                    .offset(y: 13)
            }
        }
        .onChange(of: quote?.id) { _, line in
            // Answering a line: straight into the field.
            if line != nil { focus() }
        }
        .onChange(of: focusRequest) { _, _ in focus(bySelf: true) }
        .onAppear { if focusesOnAppear { focus(bySelf: true) } }
    }

    private var field: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.notch(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).fill(Color.white.level(0.1)))
            .focused($isFocused)
            .onSubmit(send)
            // Not disabled while sending: it would lose the focus, the panel the keyboard, and on
            // getting it back the field would select the sent text (spec E-34).
            // Clicking into the field pins the notch, so it does not close while typing.
            .onChange(of: isFocused) { _, focused in
                if focused {
                    pinNotch()
                    if !focusedBySelf { service.replyFieldFocused(target) }
                } else {
                    focusedBySelf = false
                }
            }
            .onChange(of: text) { _, typed in
                if focusedBySelf, !typed.isEmpty {
                    focusedBySelf = false
                    service.replyFieldFocused(target)
                }
                let replaced = Emoticons.replace(in: typed, includingLast: false)
                if replaced != typed { text = replaced }
            }
    }

    /// The panel takes the keyboard first, then the field the focus (spec E-27).
    private func focus(bySelf: Bool = false) {
        guard status != .sending else { return }
        focusedBySelf = bySelf
        takeKeyboard()
        DispatchQueue.main.async { isFocused = true }
    }

    private var placeholder: String {
        quote == nil ? "Reply to \(service.content(for: target).sender)…" : "Answer this line…"
    }

    /// A small picker under the button (spec E-18).
    private var emojiButton: some View {
        EmojiButton(text: $text)
    }

    private var sendButton: some View {
        Button(action: send) {
            Group {
                switch status {
                case .sending: ProgressView().controlSize(.small)
                case .sent: Image(systemName: "checkmark")
                default: Image(systemName: "paperplane.fill")
                }
            }
            .font(.notch(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).fill(Self.blue))
        }
        .buttonStyle(.notch)
        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || status == .sending)
    }

    private func quoteChip(_ line: AppNotification) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.notch(size: 9))
                .foregroundStyle(Self.blue)
            Text(service.content(for: line).detail)
                .font(.notch(size: 11))
                .foregroundStyle(Color.white.level(0.6))
                .lineLimit(1)
            Spacer(minLength: 4)
            Button(action: cancelQuote) {
                Image(systemName: "xmark")
                    .font(.notch(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.level(0.5))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.notch)
            .help("Answer the whole conversation instead")
            .accessibilityLabel("Answer the whole conversation instead")
        }
        .padding(.horizontal, 10)
    }

    private var statusNote: (text: String, isError: Bool)? {
        switch status {
        case .failed(let message): (message, true)
        case .sent(let note): (note, false)
        default: nil
        }
    }

    private func send() {
        let reply = Emoticons.replace(in: text.trimmingCharacters(in: .whitespacesAndNewlines), includingLast: true)
        guard !reply.isEmpty, status != .sending else { return }
        status = .sending
        let line = quote
        let quoted = line.map { service.content(for: $0).detail }
        // Empty at once, ready for the next message; back if it did not go (spec E-34).
        let typed = text
        text = ""
        Task {
            do {
                let note = try await service.reply(to: line ?? target, text: reply, quoting: quoted)
                status = .sent(note)
                sent(reply)
            } catch {
                if text.isEmpty { text = typed }
                status = .failed("\(error)")
            }
        }
    }
}
