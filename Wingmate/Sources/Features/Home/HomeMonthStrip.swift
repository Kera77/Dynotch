import SwiftUI

/// The 1×2 Month tile: the month's name on the left, the grid beside it, its rows and letters as
/// tall as the tile allows, so it never grows past its tile (spec HT-52, HT-56).
struct HomeMonthStrip: View {
    var calendar: CalendarService
    var pager: MonthTilePager

    var body: some View {
        let month = pager.month()
        let days = HomeMonthGrid.cells(of: month)
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        let today = Calendar.current.startOfDay(for: Date())
        GeometryReader { proxy in
            let row = proxy.size.height / CGFloat(weeks.count + 1)
            let font = min(10, max(6, row * 0.72))
            HStack(alignment: .top, spacing: 8) {
                title(month, width: proxy.size.width * 0.24)
                VStack(spacing: 0) {
                    line(HomeMonthGrid.weekdayLetters().map { .letter($0) }, today: today, font: font - 1, height: row)
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        line(week.map { $0.map(Cell.day) ?? .empty } + Array(repeating: .empty, count: 7 - week.count),
                             today: today, font: font, height: row)
                    }
                }
            }
        }
        .clipped()
        .onHover { pager.isHovered = $0 }
        .onAppear { calendar.ensureLoaded(month: month) }
        .onChange(of: pager.offset) { _, _ in calendar.ensureLoaded(month: pager.month()) }
    }

    private enum Cell {
        case letter(String), day(Date), empty
    }

    private func title(_ month: Date, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(month, format: .dateTime.month(.wide))
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(pager.offset == 0 ? Theme.red : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !HomeMonthGrid.isThisYear(month) {
                Text(month, format: .dateTime.year())
                    .font(.notch(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if pager.offset != 0 {
                Button("Today") { withAnimation(Motion.quick) { pager.reset() } }
                    .buttonStyle(.plain)
                    .font(.notch(size: 10, weight: .medium))
                    .foregroundStyle(Theme.blue)
            }
        }
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func line(_ cells: [Cell], today: Date, font: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Group {
                    switch cell {
                    case .letter(let letter):
                        Text(letter).font(.notch(size: font, weight: .medium)).foregroundStyle(.secondary)
                    case .day(let day):
                        let hasEvents = (calendar.dayCounts[day] ?? 0) > 0
                        Text(day, format: .dateTime.day())
                            .font(.notch(size: font, weight: day == today ? .bold : .regular))
                            .monospacedDigit()
                            .frame(width: height * 0.92, height: height * 0.92)
                            .background(Circle().fill(day == today ? Theme.red : .clear))
                            .opacity(hasEvents || day == today ? 1 : 0.75)
                    case .empty:
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
    }
}
