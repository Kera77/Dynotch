import SwiftUI

/// Right side of the full calendar: the selected day and the following days with events.
struct AgendaListView: View {
    let days: [AgendaDay]
    let now: Date
    let join: (CalendarEvent) -> Void
    let collapse: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        section(for: day, isFirst: index == 0)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)

            CalendarIconButton(
                symbol: "arrow.down.right.and.arrow.up.left",
                help: "Compact view",
                action: collapse
            )
        }
    }

    private func section(for day: AgendaDay, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(CalendarStyle.dayTitle(day.date, now: now))
                    .font(.notch(size: isFirst ? 16 : 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(dateText(day.date, withWeek: isFirst))
                    .font(.notch(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.level(0.5))
                Spacer()
                if !day.events.isEmpty {
                    Text(day.events.count == 1 ? "1 event" : "\(day.events.count) events")
                        .font(.notch(size: 11))
                        .foregroundStyle(Color.white.level(0.5))
                        // Keep clear of the collapse button in the top-right corner.
                        .padding(.trailing, isFirst ? 32 : 0)
                }
            }
            if day.events.isEmpty {
                Text("No events")
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.level(0.75))
            } else {
                ForEach(day.events) { event in
                    AgendaEventRow(event: event, now: now) { join(event) }
                }
            }
        }
    }

    private func dateText(_ date: Date, withWeek: Bool) -> String {
        let text = date.formatted(.dateTime.month(.abbreviated).day())
        guard withWeek else { return text }
        return "\(text)  ·  Week \(Calendar.current.component(.weekOfYear, from: date))"
    }
}

private struct AgendaEventRow: View {
    let event: CalendarEvent
    let now: Date
    let join: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .trailing, spacing: 0) {
                if event.isAllDay {
                    Text("all day")
                        .font(.notch(size: 10, weight: .medium))
                } else {
                    Text(event.start.formatted(date: .omitted, time: .shortened))
                        .font(.notch(size: 11, weight: .semibold))
                    Text(CalendarAgenda.durationText(event.end.timeIntervalSince(event.start)))
                        .font(.notch(size: 10))
                        .foregroundStyle(Color.white.level(0.5))
                }
            }
            .monospacedDigit()
            .foregroundStyle(Color.white.level(0.85))
            .frame(width: 56, alignment: .trailing)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: AppleStyle.corner(1.5))
                    .fill(event.color.color)
                    .frame(width: 3, height: 20)
                Text(event.title)
                    .font(.notch(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if event.meetingURL != nil {
                    JoinButton(style: .filled, action: join)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: AppleStyle.corner(8), style: .continuous).fill(Color.white.level(0.06)))
        }
        .opacity(event.hasEnded(at: now) ? 0.45 : 1)
    }
}
