import SwiftUI

/// The notifications of a hovered badge's app, dropping down under the row (spec B-10). A line
/// opens that chat in the notch, ready to answer (spec B-10f); without any, Open starts the app.
struct BadgeDropdown: View {
    let rows: [BadgeNotificationRow]
    let openNotifications: (BadgeNotificationRow) -> Void
    let openApp: () -> Void
    /// Takes the badge out of the notch for a while (spec B-11).
    var hide: (BadgeHide.Choice) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                HStack(spacing: 8) {
                    Text("No notifications in Notification Center")
                        .font(.notch(size: 11))
                        .foregroundStyle(Color.white.level(0.6))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    hideMenu
                    Button("Open", action: openApp)
                        .buttonStyle(.notch)
                        .font(.notch(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .frame(height: 18)
                        .background(Capsule().fill(Color.white.level(0.16)))
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
            } else {
                // More than fit: the list scrolls under the pointer (spec B-10e).
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Each sender's name once, their messages under it (spec B-10b).
                        ForEach(BadgeNotificationRow.bySender(rows, limit: IndicatorLayout.badgeRows), id: \.sender) { group in
                            Button { if let first = group.rows.first { openNotifications(first) } } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(group.sender)
                                        .font(.notch(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .frame(height: IndicatorLayout.badgeSenderHeight)
                                    ForEach(group.rows) { row in
                                        HStack(spacing: 6) {
                                            Text(row.detail.isEmpty ? "—" : row.detail)
                                                .font(.notch(size: 11))
                                                .foregroundStyle(Color.white.level(0.75))
                                                .lineLimit(1)
                                            Spacer(minLength: 4)
                                            Text(row.date.formatted(date: .omitted, time: .shortened))
                                                .font(.notch(size: 9))
                                                .monospacedDigit()
                                                .foregroundStyle(Color.white.level(0.4))
                                        }
                                        .frame(height: IndicatorLayout.badgeMessageHeight)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.notch)
                        }
                    }
                    .padding(.top, 4)
                }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: IndicatorLayout.badgeDropdownHeight(rows: rows))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // On the first sender's line, which leaves the right side free.
        .overlay(alignment: .topTrailing) {
            if !rows.isEmpty {
                hideMenu
                    .frame(height: IndicatorLayout.badgeSenderHeight)
                    .padding(.top, 4)
                    .padding(.trailing, 8)
            }
        }
    }

    private var hideMenu: some View {
        Menu {
            Section("Hide This Badge") {
                ForEach(BadgeHide.Choice.allCases) { choice in
                    Button(choice.rawValue) { hide(choice) }
                }
            }
        } label: {
            Image(systemName: "eye.slash")
                .font(.notch(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.level(0.7))
                .frame(width: 22, height: 18)
                .background(Capsule().fill(Color.white.level(0.12)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Hide this badge for a while")
        .accessibilityLabel("Hide this badge")
    }
}
