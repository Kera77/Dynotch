import SwiftUI

/// The hours a day's timeline spans: 8–20, wider for earlier or later events (spec K-14).
enum TimelineRange {
    static func hours(for events: [CalendarEvent], on day: Date, calendar: Calendar = .current) -> ClosedRange<Int> {
        let timed = events.filter { !$0.isAllDay }
        let starts = timed.map { max(calendar.component(.hour, from: max($0.start, calendar.startOfDay(for: day))), 0) }
        let ends = timed.map { event -> Int in
            let end = min(event.end, calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) ?? event.end)
            let hour = calendar.component(.hour, from: end)
            return calendar.component(.minute, from: end) > 0 || hour == 0 ? min(hour + 1, 24) : hour
        }
        return min(8, starts.min() ?? 8)...max(20, ends.max() ?? 20)
    }

    /// Where a moment sits on the timeline, 0…1.
    static func position(of date: Date, in hours: ClosedRange<Int>, on day: Date, calendar: Calendar = .current) -> Double {
        let start = calendar.date(bySettingHour: hours.lowerBound, minute: 0, second: 0, of: day) ?? day
        let span = Double(hours.upperBound - hours.lowerBound) * 3600
        return min(max(date.timeIntervalSince(start) / span, 0), 1)
    }
}

/// The day on one line (spec K-14): events as coloured bars, the hours, a "now" line, and the
/// next meeting with a link highlighted; a click on it joins.
struct DayTimelineView: View {
    let events: [CalendarEvent]
    let day: Date
    let now: Date
    let join: (CalendarEvent) -> Void

    private var hours: ClosedRange<Int> { TimelineRange.hours(for: events, on: day) }

    private var nextMeeting: CalendarEvent? {
        events.filter { !$0.isAllDay && $0.meetingURL != nil && $0.end > now }.min { $0.start < $1.start }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(height: 14).offset(y: 3)
                ForEach(events.filter { !$0.isAllDay }) { event in
                    bar(event, width: width)
                }
                ForEach(Array(stride(from: hours.lowerBound, through: hours.upperBound, by: 2)), id: \.self) { hour in
                    Text("\(hour)")
                        .font(.system(size: 8, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.4))
                        .position(x: x(hour: hour, width: width), y: 26)
                }
                if Calendar.current.isDate(now, inSameDayAs: day) {
                    Rectangle()
                        .fill(Theme.red)
                        .frame(width: 2, height: 20)
                        .offset(x: TimelineRange.position(of: now, in: hours, on: day) * width - 1)
                }
            }
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's timeline, \(events.count) events")
    }

    private func x(hour: Int, width: Double) -> Double {
        Double(hour - hours.lowerBound) / Double(max(hours.upperBound - hours.lowerBound, 1)) * width
    }

    private func bar(_ event: CalendarEvent, width: Double) -> some View {
        let start = TimelineRange.position(of: event.start, in: hours, on: day) * width
        let end = TimelineRange.position(of: event.end, in: hours, on: day) * width
        let isNext = event.id == nextMeeting?.id
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(event.color.color.opacity(event.hasEnded(at: now) ? 0.35 : 0.9))
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(Color.white, lineWidth: isNext ? 1.5 : 0))
            .frame(width: max(end - start, 3), height: 14)
            .offset(x: start, y: 3)
            .help(event.title + (isNext ? " – click to join" : ""))
            .onTapGesture { if event.meetingURL != nil { join(event) } }
    }
}
