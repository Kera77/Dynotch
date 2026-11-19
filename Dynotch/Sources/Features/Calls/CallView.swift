import SwiftUI

/// An incoming call in the notch (spec P-1…P-3): who calls, and buttons to text, decline and
/// answer.
struct CallView: View {
    @ObservedObject var service: CallService
    let call: IncomingCall
    let notchHeight: CGFloat

    static let rowHeight: CGFloat = 58
    static let composeHeight: CGFloat = 44
    private static var red: Color { Color.red }
    private static var green: Color { Color.green }

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 10) {
                avatar
                // Only the name (spec P-1): no line or number labels.
                Text(service.contact?.name ?? call.caller)
                    .font(.notch(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                roundButton("message.fill", color: service.isComposing ? ClaudeUsageView.blue : Color.white.level(0.22),
                            help: "Reply with a message") { service.toggleComposing() }
                roundButton("phone.down.fill", color: Self.red, help: "Decline") { service.decline() }
                roundButton("phone.fill", color: Self.green, help: "Answer") { service.accept() }
            }
            .padding(.horizontal, 14)
            .frame(height: Self.rowHeight)

            if service.isComposing { composer }
        }
    }

    private var avatar: some View {
        let initials = CallMatcher.initials(of: service.contact?.name ?? call.caller)
        return ZStack {
            Circle().fill(Color.white.level(0.18))
            if let data = service.contact?.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.notch(size: 15))
                    .foregroundStyle(Color.white.level(0.8))
            } else {
                Text(initials)
                    .font(.notch(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 36, height: 36)
    }

    private func roundButton(_ symbol: String, color: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.notch(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color))
                .contentShape(Circle())
        }
        .buttonStyle(.notch)
        .help(help)
    }

    /// Enter sends the text to the caller.
    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Message to \(service.contact?.name ?? call.caller) — Enter sends", text: $service.draft)
                .textFieldStyle(.plain)
                .font(.notch(size: 12))
                .foregroundStyle(.white)
                .focused($isFieldFocused)
                .onSubmit { service.sendMessage() }
                .disabled(service.isSending)
            if service.isSending {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).fill(Color.white.level(0.12)))
        .padding(.horizontal, 14)
        .frame(height: Self.composeHeight, alignment: .top)
        .overlay(alignment: .bottomLeading) {
            if let error = service.sendError {
                Text(error)
                    .font(.notch(size: 10))
                    .foregroundStyle(Color.red)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 1)
            }
        }
        .onAppear { isFieldFocused = true }
    }
}
