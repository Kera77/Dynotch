import SwiftUI

/// Day strip on top, the selected day's events below (spec K-4, K-5).
struct CalendarCompactView: View {
    @Bindable var service: CalendarService
    let expand: () -> Void
    /// The meeting in progress or the next one at the top, set before the first frame: scrolling
    /// there a frame later made the opening jerk (spec K-5b, K-16).
    @State private var topEvent: String?

    init(service: CalendarService, expand: @escaping () -> Void) {
        self.service = service
        self.expand = expand
        _topEvent = State(initialValue: CalendarAgenda.focusEvent(in: service.events(on: service.selectedDay), now: service.now)?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // The month is written small under the days (spec K-15), not in a column.
                DayStripView(
                    selectedDay: $service.selectedDay,
                    today: service.today,
                    counts: service.dayCounts
                )
                if service.selectedDay != service.today {
                    // Back to today, only when away from it (spec K-15).
                    Button {
                        withAnimation(Motion.quick) { service.selectedDay = service.today }
                    } label: {
                        Text("Today")
                            .font(.notch(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(Capsule().fill(Theme.blue))
                    }
                    .buttonStyle(.notch)
                    .help("Back to today")
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .padding(.leading, 6)
                }
                CalendarIconButton(
                    symbol: "arrow.up.left.and.arrow.down.right",
                    help: "Full calendar",
                    action: expand
                )
                .padding(.leading, 8)
            }
            .frame(height: NotchGeometry.dayStripHeight)

            dayContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var dayContent: some View {
        let events = service.events(on: service.selectedDay)
        if events.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.notch(size: 16))
                Text(service.selectedDay == service.today ? "Nothing for today" : "Nothing on this day")
                    .font(.notch(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.white.level(0.55))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            DayTimelineView(events: events, day: service.selectedDay, now: service.now) { service.join($0) }
                .padding(.top, 4)
            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        CompactEventRow(event: event, now: service.now) { service.join(event) }
                            .id(event.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 6)
            }
            .initialScroll(to: $topEvent, anchor: .top)
            .scrollIndicators(.never)
            .onChange(of: service.selectedDay) { _, day in
                topEvent = CalendarAgenda.focusEvent(in: service.events(on: day), now: service.now)?.id
            }
            .onChange(of: CalendarAgenda.focusEvent(in: events, now: service.now)?.id) { _, id in
                withAnimation(Motion.quick) { topEvent = id }
            }
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
                    .font(.notch(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(timeText)
                    .font(.notch(size: 11, weight: .medium))
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
        if event.isAllDay { return "\(weekday) · all day" }
        return "\(weekday) \(event.start.formatted(date: .omitted, time: .shortened))"
    }
}
