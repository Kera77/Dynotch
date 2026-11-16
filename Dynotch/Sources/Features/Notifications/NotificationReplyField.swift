import SwiftUI

/// A text field that answers a notification's chat (spec E-11): Enter or the button sends.
struct NotificationReplyField: View {
    let service: NotificationService
    /// The reply goes to this message's chat.
    let target: AppNotification

    @State private var text = ""
    @State private var status: Status = .idle

    enum Status: Equatable {
        case idle
        case sending
        case sent(String)
        case failed(String)
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Reply to \(service.content(for: target).sender)…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.1)))
                .onSubmit(send)
                .disabled(status == .sending)
            Button(action: send) {
                Group {
                    switch status {
                    case .sending: ProgressView().controlSize(.small)
                    case .sent: Image(systemName: "checkmark")
                    default: Image(systemName: "paperplane.fill")
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(red: 0.04, green: 0.52, blue: 1)))
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || status == .sending)
        }
        .overlay(alignment: .bottomLeading) {
            if let note = statusNote {
                Text(note.text)
                    .font(.system(size: 10))
                    .foregroundStyle(note.isError ? Color(red: 1, green: 0.45, blue: 0.4) : Color.white.opacity(0.5))
                    .lineLimit(1)
                    .padding(.horizontal, 2)
                    .offset(y: 13)
            }
        }
    }

    private var statusNote: (text: String, isError: Bool)? {
        switch status {
        case .failed(let message): (message, true)
        case .sent(let note): (note, false)
        default: nil
        }
    }

    private func send() {
        let reply = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty, status != .sending else { return }
        status = .sending
        Task {
            do {
                let note = try await service.reply(to: target, text: reply)
                text = ""
                status = .sent(note)
            } catch {
                status = .failed("\(error)")
            }
        }
    }
}
