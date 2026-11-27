import SwiftUI

/// The compact row under the notification hanging below the notch: an earlier sender's
/// notification, or the sticky notice (spec E-28). A line of light like the panel's rim parts it
/// from the one above (spec E-29).
struct PeekSecondRowView: View {
    let row: PeekSecondRow
    let app: NotificationApp?
    let content: NotificationContent?
    /// The small X, like on the row above; nil: none (spec E-35).
    var dismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            PeekDivider()
            HStack(spacing: 6) {
                icon
                Text(title)
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.level(0.9))
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.notch(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.level(0.5))
                        .lineLimit(1)
                        .layoutPriority(-1)
                }
                Spacer(minLength: 0)
                if let dismiss {
                    Button(action: dismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.notch(size: 12))
                            .foregroundStyle(Color.white.level(0.55))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.notch)
                    .help("Dismiss")
                    .accessibilityLabel("Dismiss \(title)")
                }
            }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var icon: some View {
        switch row {
        case .notification:
            if let app { AppIconView(app: app, size: 14) }
        case .notice(let notice):
            NoticeIcon(notice: notice).frame(width: 16, height: 16)
        }
    }

    private var title: String {
        switch row {
        case .notification: content?.sender ?? ""
        case .notice(let notice): notice.title
        }
    }

    private var subtitle: String? {
        switch row {
        case .notification:
            guard let app, let content, content.sender != app.name else { return nil }
            return app.name
        case .notice(let notice):
            return [notice.detail, notice.date.formatted(date: .omitted, time: .shortened)]
                .filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }
}

/// Full width and brightest at its ends, where it meets the rim light (spec D-14a, E-29).
struct PeekDivider: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.16), location: 0),
                .init(color: .white.opacity(0.06), location: 0.3),
                .init(color: .white.opacity(0.06), location: 0.7),
                .init(color: .white.opacity(0.16), location: 1)
            ],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: 0.75)
        .allowsHitTesting(false)
    }
}
