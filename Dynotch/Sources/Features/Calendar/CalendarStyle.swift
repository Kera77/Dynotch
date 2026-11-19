import SwiftUI

/// Shared colors and texts of the calendar views.
enum CalendarStyle {
    static var accent: Color { Theme.blue }
    static let weekend = Color(red: 0.86, green: 0.42, blue: 0.4)
    /// Date and time under a meeting's name (spec K-5).
    static let eventTime = Color(red: 0.3, green: 0.62, blue: 1)
    static var joinGreen: Color { Color.green }

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
        /// Grey capsule, white text: under the closed notch, beside the coloured countdown (spec K-8j).
        case muted
    }

    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "video")
                    .font(.notch(size: 10, weight: .semibold))
                Text("Join")
                    .font(.notch(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background)
            .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
    }

    private var foreground: Color {
        switch style {
        case .filled: Color.black.opacity(0.85)
        case .subtle: CalendarStyle.accent
        case .muted: Color.white.level(0.9)
        }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .filled:
            Capsule(style: .continuous).fill(CalendarStyle.joinGreen)
        case .muted:
            Capsule(style: .continuous).fill(Color.white.level(0.16))
        case .subtle:
            RoundedRectangle(cornerRadius: AppleStyle.corner(6), style: .continuous).fill(Color.white.level(0.08))
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
                .font(.notch(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.level(0.8))
                .frame(width: 24, height: 20)
                .background(RoundedRectangle(cornerRadius: AppleStyle.corner(6), style: .continuous).fill(Color.white.level(0.1)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.notch)
        .help(help)
    }
}
