import SwiftUI

/// Capsule outline that starts at the top centre and runs clockwise, so trimming its start
/// makes the line disappear clockwise.
struct ClockwiseCapsule: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.height, rect.width) / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.midY), radius: radius,
            startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.midY), radius: radius,
            startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// Shown beside the closed notch before and during an event (spec K-7…K-9): icon on the left,
/// countdown on the right inside a capsule whose outline shows the time left and runs down
/// clockwise.
struct UpcomingEventIndicator: View {
    let event: CalendarEvent
    let leadTime: TimeInterval
    let notchWidth: CGFloat
    let sideWidth: CGFloat

    private static let lineWidth: CGFloat = 1.5

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let status = CalendarAgenda.status(of: event, now: context.date, leadTime: leadTime)
            let color = Self.color(for: status.phase)
            HStack(spacing: 0) {
                Image(systemName: event.meetingURL != nil ? "video.fill" : "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: sideWidth)
                Color.clear.frame(width: notchWidth)
                countdown(status: status, color: color)
                    .frame(width: sideWidth)
            }
        }
        .help(event.title)
    }

    private func countdown(status: EventStatus, color: Color) -> some View {
        Text(CalendarAgenda.countdownText(status.remaining))
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(width: 46, height: 18)
            .background(ClockwiseCapsule().stroke(Color.white.opacity(0.14), lineWidth: Self.lineWidth))
            .overlay(
                // What is left of the lead time or of the meeting; it shrinks clockwise.
                ClockwiseCapsule()
                    .trim(from: status.progress, to: 1)
                    .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                    .animation(.linear(duration: 1), value: status.progress)
            )
    }

    static func color(for phase: EventStatus.Phase) -> Color {
        switch phase {
        case .upcoming: Color(red: 1, green: 0.8, blue: 0.25)
        case .imminent: Color(red: 1, green: 0.3, blue: 0.3)
        case .ongoing: Color(red: 0.45, green: 0.78, blue: 1)
        }
    }
}
