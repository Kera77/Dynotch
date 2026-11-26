import SwiftUI

/// The compact row under the notification hanging below the notch: an earlier sender's
/// notification, or the sticky notice (spec E-28). A hairline parts it from the one above.
struct PeekSecondRowView: View {
    let row: PeekSecondRow
    let app: NotificationApp?
    let content: NotificationContent?

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.level(0.1))
                .frame(height: 0.5)
                .padding(.horizontal, 12)
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
            }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
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
