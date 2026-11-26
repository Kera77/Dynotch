import SwiftUI

/// Horizontally scrolling row of days; tap a day to select it (spec K-4).
struct DayStripView: View {
    @Binding var selectedDay: Date
    let today: Date
    let counts: [Date: Int]
    /// How many days each side of today: two weeks in the module, two on the Days tile (spec K-15, HT-46).
    var span = DayStripView.reach

    /// Two weeks back and two weeks ahead of today (spec K-15).
    nonisolated static let reach = 14

    /// Today ± the span; around the selected day if the full calendar chose one further away.
    private var days: [Date] {
        Self.days(around: today, selected: selectedDay, span: span)
    }

    /// The day kept within the span (two weeks) of today.
    nonisolated static func clamped(_ day: Date, around today: Date, span: Int = reach, calendar: Calendar = .current) -> Date {
        let distance = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        guard abs(distance) > span else { return day }
        return calendar.date(byAdding: .day, value: distance > 0 ? span : -span, to: today) ?? day
    }

    nonisolated static func days(around today: Date, selected: Date, span: Int = reach, calendar: Calendar = .current) -> [Date] {
        let distance = abs(calendar.dateComponents([.day], from: today, to: selected).day ?? 0)
        let anchor = distance <= span ? today : selected
        return (-span...span).compactMap { calendar.date(byAdding: .day, value: $0, to: anchor) }
    }

    /// The day in the middle of the strip, set before the first frame: scrolling there a frame
    /// later made the opening jerk (spec K-16).
    @State private var centred: Date?

    init(selectedDay: Binding<Date>, today: Date, counts: [Date: Int], span: Int = DayStripView.reach) {
        _selectedDay = selectedDay
        self.today = today
        self.counts = counts
        self.span = span
        _centred = State(initialValue: selectedDay.wrappedValue)
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    DayCell(
                        day: day,
                        isToday: day == today,
                        isSelected: day == selectedDay,
                        hasEvents: (counts[day] ?? 0) > 0
                    )
                    .id(day)
                    .onTapGesture {
                        withAnimation(Motion.quick) { selectedDay = day }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .initialScroll(to: $centred, anchor: .center)
        .scrollIndicators(.never)
        // Five days fit whole: no fading edges there (spec HT-46).
        .mask(span < DayStripView.reach ? LinearGradient(colors: [.black], startPoint: .leading, endPoint: .trailing) : edgeFade)
        // The selected day's month, small in the gap under the days (spec K-15).
        .overlay(alignment: .bottomLeading) {
            Text(selectedDay.formatted(.dateTime.month(.wide)))
                .font(.notch(size: 9, weight: .semibold))
                .foregroundStyle(Color.white.level(0.55))
                // No backing of its own: it would stand as a black patch on glass (spec K-15b).
                .padding(.leading, 6)
                .allowsHitTesting(false)
        }
        .onChange(of: selectedDay) { _, day in
            withAnimation(Motion.quick) { centred = day }
        }
    }

    private var edgeFade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.1),
                .init(color: .black, location: 0.92),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct DayCell: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let hasEvents: Bool

    private var isHighlighted: Bool { isToday || isSelected }

    private var isFirstOfMonth: Bool { Calendar.current.component(.day, from: day) == 1 }

    private var color: Color {
        if isToday { return CalendarStyle.accent }
        if isSelected { return .white }
        if Calendar.current.isDateInWeekend(day) { return CalendarStyle.weekend.opacity(0.8) }
        return Color.white.level(0.6)
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(weekdayText)
                .font(.notch(size: 9, weight: isHighlighted ? .bold : .semibold))
                .foregroundStyle(isHighlighted ? color : color.opacity(0.7))
            Text(day.formatted(.dateTime.day()))
                .font(.notch(size: isHighlighted ? 20 : 15, weight: isHighlighted ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(height: 24)
            Circle()
                .fill(hasEvents ? CalendarStyle.accent : .clear)
                .frame(width: 4, height: 4)
            // Where a new month starts (spec K-15).
            Text(isFirstOfMonth ? day.formatted(.dateTime.month(.abbreviated)) : " ")
                .font(.notch(size: 8, weight: .bold))
                .foregroundStyle(Color.white.level(0.55))
                .frame(height: 10)
        }
        .overlay(alignment: .leading) {
            if isFirstOfMonth {
                Rectangle().fill(Color.white.level(0.18)).frame(width: 1).padding(.vertical, 6)
            }
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    static let width: CGFloat = 36

    private var weekdayText: String {
        let style: Date.FormatStyle.Symbol.Weekday = isHighlighted ? .abbreviated : .narrow
        return day.formatted(.dateTime.weekday(style)).uppercased()
    }
}
