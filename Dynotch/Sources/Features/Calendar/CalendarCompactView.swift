import SwiftUI

/// Day strip on top, the selected day's events below (spec K-4, K-5).
struct CalendarCompactView: View {
    @ObservedObject var service: CalendarService
    let expand: () -> Void

    private static let leadingColumn: CGFloat = 52

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(service.selectedDay.formatted(.dateTime.month(.abbreviated)).capitalized)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: Self.leadingColumn, alignment: .leading)
                DayStripView(
                    selectedDay: $service.selectedDay,
                    today: service.today,
                    counts: service.dayCounts
                )
            }
            .frame(height: NotchGeometry.dayStripHeight)

            ZStack(alignment: .topLeading) {
                dayContent
                CalendarIconButton(
                    symbol: "arrow.up.left.and.arrow.down.right",
                    help: "Teljes naptár",
                    action: expand
                )
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var dayContent: some View {
        let events = service.events(on: service.selectedDay)
        if events.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 16))
                Text(service.selectedDay == service.today ? "Mára nincs esemény" : "Erre a napra nincs esemény")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.white.opacity(0.55))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        CompactEventRow(event: event, now: service.now) { service.join(event) }
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.never)
            .padding(.leading, Self.leadingColumn)
        }
    }
}

private struct CompactEventRow: View {
    let event: CalendarEvent
    let now: Date
    let join: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(timeText)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(CalendarStyle.eventTime)
            }
            Spacer(minLength: 8)
            if event.meetingURL != nil {
                JoinButton(style: .filled, action: join)
            }
        }
        .opacity(event.hasEnded(at: now) ? 0.45 : 1)
    }

    private var timeText: String {
        let weekday = event.start.formatted(.dateTime.weekday(.abbreviated)).capitalized
        if event.isAllDay { return "\(weekday) · egész nap" }
        return "\(weekday) \(event.start.formatted(date: .omitted, time: .shortened))"
    }
}
