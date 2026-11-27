import SwiftUI

/// One message as in chat apps (spec E-33): the others' on the left in grey, mine on the right in
/// blue; a new one slides in from its own side. The accessory (e.g. the line's reply arrow)
/// stands beside the bubble, on the side of the free space.
struct MessageBubble<Content: View, Accessory: View>: View {
    let mine: Bool
    var highlighted = false
    @ViewBuilder var content: () -> Content
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            if mine {
                Spacer(minLength: 36)
                accessory()
            }
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: AppleStyle.corner(10), style: .continuous).fill(fill))
            if !mine {
                accessory()
                Spacer(minLength: 36)
            }
        }
        .transition(Self.slideIn(mine: mine))
    }

    private var fill: Color {
        mine ? Theme.blue.opacity(highlighted ? 1 : 0.8) : Color.white.level(highlighted ? 0.16 : 0.08)
    }

    static func slideIn(mine: Bool) -> AnyTransition {
        .move(edge: mine ? .trailing : .leading).combined(with: .opacity)
    }
}

extension MessageBubble where Accessory == EmptyView {
    init(mine: Bool, highlighted: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.init(mine: mine, highlighted: highlighted, content: content, accessory: { EmptyView() })
    }
}

/// A bubble's text with its time after it.
struct MessageBubbleText: View {
    let text: Text
    var time: Date?
    var mine = false
    var size: CGFloat = 12

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            text
                .font(.notch(size: size))
                .foregroundStyle(Color.white.level(mine ? 1 : 0.9))
                .fixedSize(horizontal: false, vertical: true)
            if let time {
                Text(time.formatted(date: .omitted, time: .shortened))
                    .font(.notch(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.level(mine ? 0.75 : 0.4))
                    .fixedSize()
            }
        }
    }
}

/// A notification's messages as bubbles (spec E-33): Google Chat's lines one by one, mine on the
/// right; other apps' text as one bubble from the sender.
struct NotificationBubbles<Accessory: View>: View {
    let content: NotificationContent
    let date: Date
    var size: CGFloat = 12
    var loading = false
    var highlighted = false
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if loading {
                MessageBubble(mine: false) { MessageBubbleText(text: Text("Loading messages…"), size: size) }
            } else if content.lines.isEmpty {
                MessageBubble(mine: false, highlighted: highlighted) {
                    MessageBubbleText(text: content.detailText(), time: date, size: size)
                } accessory: { accessory() }
            } else {
                ForEach(Array(content.lines.enumerated()), id: \.offset) { index, line in
                    let last = index == content.lines.count - 1
                    MessageBubble(mine: line.isMine, highlighted: highlighted && !line.isMine) {
                        MessageBubbleText(text: content.bubbleText(line), time: last ? date : nil, mine: line.isMine, size: size)
                    } accessory: {
                        if last { accessory() }
                    }
                }
            }
        }
    }
}

extension NotificationBubbles where Accessory == EmptyView {
    init(content: NotificationContent, date: Date, size: CGFloat = 12, loading: Bool = false) {
        self.init(content: content, date: date, size: size, loading: loading, accessory: { EmptyView() })
    }
}

extension NotificationContent {
    /// One line in its bubble: the group sender before the others' text (spec GW-32).
    func bubbleText(_ message: ChatWebMessage) -> Text {
        guard !message.isMine, let name = shownSender(of: message) else { return Text(message.text) }
        return Text("\(Text("\(name): ").fontWeight(.semibold))\(message.text)")
    }
}
