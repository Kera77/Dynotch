import SwiftUI

/// Shared colors and texts of the calendar views.
enum CalendarStyle {
    static let accent = Color(red: 0.04, green: 0.52, blue: 1)
    static let weekend = Color(red: 0.86, green: 0.42, blue: 0.4)
    static let eventTime = Color(red: 1, green: 0.27, blue: 0.35)
    static let joinGreen = Color(red: 0.19, green: 0.74, blue: 0.33)

    /// "Today", "Tomorrow", otherwise the weekday name.
    static func dayTitle(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return date.formatted(.dateTime.weekday(.wide)).capitalized
    }
}

extension CalendarColor {
    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

/// "Join" button; opens the meeting in the default browser.
struct JoinButton: View {
    enum Style {
        /// Green capsule (compact day view).
        case filled
        /// Blue text on a dark tile (full calendar).
        case subtle
    }

    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "video")
                    .font(.system(size: 10, weight: .semibold))
                Text("Join")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(style == .filled ? Color.black.opacity(0.85) : CalendarStyle.accent)
            .background(background)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .filled:
            Capsule(style: .continuous).fill(CalendarStyle.joinGreen)
        case .subtle:
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.08))
        }
    }
}

/// Small square icon button (expand/collapse, month navigation).
struct CalendarIconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: 24, height: 20)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.1)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
