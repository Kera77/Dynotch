import SwiftUI

/// Horizontally scrolling row of days; tap a day to select it (spec K-4).
struct DayStripView: View {
    @Binding var selectedDay: Date
    let today: Date
    let counts: [Date: Int]

    private static let daysBefore = 14
    private static let dayCount = 60

    /// Normally around today; around the selected day if that is far away.
    private var days: [Date] {
        let calendar = Calendar.current
        let distance = abs(calendar.dateComponents([.day], from: today, to: selectedDay).day ?? 0)
        let anchor = distance < Self.daysBefore ? today : selectedDay
        return (0..<Self.dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0 - Self.daysBefore, to: anchor)
        }
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
