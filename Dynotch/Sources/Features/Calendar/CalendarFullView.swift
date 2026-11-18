import SwiftUI

/// Full calendar in the large panel: month grid on the left, agenda on the right (spec K-10…K-12).
struct CalendarFullView: View {
    @ObservedObject var service: CalendarService
    let collapse: () -> Void

    @State private var displayedMonth = Date()
    /// The month grows with a resized module (spec RS-5).
    @State private var width: CGFloat = 0

    nonisolated static func monthWidth(for width: CGFloat) -> CGFloat {
        Responsive.share(0.3, of: width, in: 256...380)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            MonthGridView(
                month: displayedMonth,
                selectedDay: service.selectedDay,
                today: service.today,
                counts: service.dayCounts,
                select: select,
                changeMonth: changeMonth
            )
            .frame(width: Self.monthWidth(for: width))

            AgendaListView(
                days: service.agenda(startingAt: service.selectedDay),
                now: service.now,
                join: service.join,
                collapse: collapse
            )
        }
        .padding(.top, 6)
        .readWidth($width)
        .onAppear { displayedMonth = service.selectedDay }
    }

    private func select(_ day: Date) {
        service.selectedDay = day
        if !Calendar.current.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = day
            service.ensureLoaded(month: day)
        }
    }

    private func changeMonth(_ delta: Int) {
        guard let month = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = month
        service.ensureLoaded(month: month)
    }
}

private struct MonthGridView: View {
    let month: Date
    let selectedDay: Date
    let today: Date
    let counts: [Date: Int]
    let select: (Date) -> Void
    let changeMonth: (Int) -> Void

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        let days = CalendarAgenda.monthGrid(for: month)
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(month.formatted(.dateTime.year().month(.wide)).capitalized)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                CalendarIconButton(symbol: "chevron.left", help: "Previous month") { changeMonth(-1) }
                CalendarIconButton(symbol: "chevron.right", help: "Next month") { changeMonth(1) }
            }
            LazyVGrid(columns: Self.columns, spacing: 0) {
                ForEach(days.prefix(7), id: \.self) { day in
                    Text(day.formatted(.dateTime.weekday(.narrow)).uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .frame(height: 16)
                }
                ForEach(days, id: \.self) { day in
                    MonthDayCell(
                        day: day,
                        isInMonth: Calendar.current.isDate(day, equalTo: month, toGranularity: .month),
                        isToday: day == today,
                        isSelected: day == selectedDay,
                        eventCount: counts[day] ?? 0
                    )
                    .onTapGesture { select(day) }
                }
            }
        }
    }
}

private struct MonthDayCell: View {
    let day: Date
    let isInMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let eventCount: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(day.formatted(.dateTime.day()))
                .font(.system(size: 12, weight: isToday || isInMonth ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : Color.white.opacity(isInMonth ? 0.9 : 0.35))
                .frame(width: 24, height: 24)
                .background(Circle().fill(circleColor))
            HStack(spacing: 2) {
                ForEach(0..<min(eventCount, 3), id: \.self) { _ in
                    Circle()
                        .fill(CalendarStyle.accent.opacity(isInMonth ? 1 : 0.5))
                        .frame(width: 3, height: 3)
                }
            }
            .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .contentShape(Rectangle())
    }

    private var circleColor: Color {
        if isToday { return CalendarStyle.accent }
        return isSelected ? Color.white.opacity(0.18) : .clear
    }
}
