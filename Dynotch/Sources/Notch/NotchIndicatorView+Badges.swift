import SwiftUI

/// The notifications of a hovered badge's app, dropping down under the row (spec B-10). A line
/// opens the app's notifications in the notch; without any, Open starts the app.
struct BadgeDropdown: View {
    let rows: [BadgeNotificationRow]
    let openNotifications: () -> Void
    let openApp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                HStack(spacing: 8) {
                    Text("No notifications in Notification Center")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Button("Open", action: openApp)
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 18)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
            } else {
                ForEach(rows.prefix(IndicatorLayout.badgeRows)) { row in
                    Button(action: openNotifications) {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text(row.sender)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(row.date.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 9))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.white.opacity(0.4))
                            }
                            Text(row.detail.isEmpty ? "—" : row.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.75))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
