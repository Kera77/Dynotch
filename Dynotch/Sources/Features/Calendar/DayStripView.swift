import SwiftUI

/// Horizontally scrolling row of days; tap a day to select it (spec K-4).
struct DayStripView: View {
    @Binding var selectedDay: Date
    let today: Date
    let counts: [Date: Int]

    /// Two weeks back and two weeks ahead of today (spec K-15).
    static let reach = 14

    /// Today ± two weeks; around the selected day if the full calendar chose one further away.
    private var days: [Date] {
        Self.days(around: today, selected: selectedDay)
    }

    /// The day kept within two weeks of today.
    nonisolated static func clamped(_ day: Date, around today: Date, calendar: Calendar = .current) -> Date {
        let distance = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        guard abs(distance) > reach else { return day }
        return calendar.date(byAdding: .day, value: distance > 0 ? reach : -reach, to: today) ?? day
    }

    nonisolated static func days(around today: Date, selected: Date, calendar: Calendar = .current) -> [Date] {
        let distance = abs(calendar.dateComponents([.day], from: today, to: selected).day ?? 0)
        let anchor = distance <= reach ? today : selected
        return (-reach...reach).compactMap { calendar.date(byAdding: .day, value: $0, to: anchor) }
    }

    var body: some View {
        ScrollViewReader { proxy in
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
                            withAnimation(.easeOut(duration: 0.2)) { selectedDay = day }
                        }
                    }
                }
            }
            .scrollIndicators(.never)
            .mask(edgeFade)
            // The selected day's month, small in the gap under the days (spec K-15).
            .overlay(alignment: .bottomLeading) {
                Text(selectedDay.formatted(.dateTime.month(.wide)))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.horizontal, 4)
                    .background(Color.black)
                    .padding(.leading, 2)
                    .allowsHitTesting(false)
            }
            .onAppear {
                DispatchQueue.main.async { proxy.scrollTo(selectedDay, anchor: .center) }
            }
            .onChange(of: selectedDay) { _, day in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(day, anchor: .center) }
            }
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

private struct DayCell: View {
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
        return Color.white.opacity(0.6)
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(weekdayText)
                .font(.system(size: 9, weight: isHighlighted ? .bold : .semibold))
                .foregroundStyle(isHighlighted ? color : color.opacity(0.7))
            Text(day.formatted(.dateTime.day()))
                .font(.system(size: isHighlighted ? 20 : 15, weight: isHighlighted ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(height: 24)
            Circle()
                .fill(hasEvents ? CalendarStyle.accent : .clear)
                .frame(width: 4, height: 4)
            // Where a new month starts (spec K-15).
            Text(isFirstOfMonth ? day.formatted(.dateTime.month(.abbreviated)) : " ")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(height: 10)
        }
        .overlay(alignment: .leading) {
            if isFirstOfMonth {
                Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1).padding(.vertical, 6)
            }
        }
        .frame(width: 36)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private var weekdayText: String {
        let style: Date.FormatStyle.Symbol.Weekday = isHighlighted ? .abbreviated : .narrow
        return day.formatted(.dateTime.weekday(style)).uppercased()
    }
}
