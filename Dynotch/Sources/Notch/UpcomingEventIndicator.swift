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

/// Where the countdowns sit beside the closed notch. Slot `i` holds a countdown capsule on the
/// right and the matching icon, mirrored, on the left. Shared by the view and the hover hit test.
struct IndicatorLayout: Equatable {
    static let slotWidth: CGFloat = 46
    static let capsuleHeight: CGFloat = 18
    static let spacing: CGFloat = 6
    static let padding: CGFloat = 7
    static let minimumSideWidth: CGFloat = 60
    /// Extra height for the meeting name shown on hover (spec K-8d).
    static let labelHeight: CGFloat = 26
    static let labelWidth: CGFloat = 360

    let count: Int

    var sideWidth: CGFloat {
        guard count > 0 else { return 0 }
        let slots = CGFloat(count) * Self.slotWidth + CGFloat(count - 1) * Self.spacing
        return max(Self.minimumSideWidth, 2 * Self.padding + slots)
    }

    /// Size of the closed notch with the countdowns, and with the hover label.
    func size(notch: CGSize, showsLabel: Bool) -> CGSize {
        guard count > 0 else { return notch }
        let width = notch.width + 2 * sideWidth
        guard showsLabel else { return CGSize(width: width, height: notch.height) }
        return CGSize(width: max(width, Self.labelWidth), height: notch.height + Self.labelHeight)
    }

    /// Horizontal centres of slot `index`: icon on the left, countdown on the right of the notch.
    func centers(of index: Int, notchRect: CGRect) -> (left: CGFloat, right: CGFloat) {
        let offset = Self.padding + Self.slotWidth / 2 + CGFloat(index) * (Self.slotWidth + Self.spacing)
        return (notchRect.minX - offset, notchRect.maxX + offset)
    }

    /// The slot under a point (global coordinates), if any.
    func slot(at point: CGPoint, notchRect: CGRect) -> Int? {
        guard point.y >= notchRect.minY, point.y <= notchRect.maxY + NotchGeometry.topEdgeTolerance else { return nil }
        let reach = (Self.slotWidth + Self.spacing) / 2
        return (0..<count).first { index in
            let centers = centers(of: index, notchRect: notchRect)
            return abs(point.x - centers.left) <= reach || abs(point.x - centers.right) <= reach
        }
    }
}

/// Shown beside the closed notch before and during events (spec K-7…K-9): icons on the left,
/// countdowns on the right inside capsules whose outline shows the time left and runs down
/// clockwise. The hovered one's name is written below the notch.
struct UpcomingEventIndicator: View {
    let events: [CalendarEvent]
    let leadTime: TimeInterval
    let notchSize: CGSize
    let hoveredIndex: Int?

    private static let lineWidth: CGFloat = 1.5

    private var layout: IndicatorLayout { IndicatorLayout(count: events.count) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    icons(now: context.date)
                    Color.clear.frame(width: notchSize.width)
                    countdowns(now: context.date)
                }
                .frame(height: notchSize.height)

                if let hoveredIndex, events.indices.contains(hoveredIndex) {
                    label(for: events[hoveredIndex], now: context.date)
                }
            }
        }
    }

    /// Icons mirrored on the left: slot 0 is closest to the notch.
    private func icons(now: Date) -> some View {
        HStack(spacing: IndicatorLayout.spacing) {
            ForEach(Array(events.enumerated().reversed()), id: \.element.id) { index, event in
                let color = Self.color(for: CalendarAgenda.status(of: event, now: now, leadTime: leadTime).phase)
                Image(systemName: event.meetingURL != nil ? "video.fill" : "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: IndicatorLayout.slotWidth, height: IndicatorLayout.capsuleHeight)
                    .opacity(hoveredIndex == nil || hoveredIndex == index ? 1 : 0.45)
            }
        }
        .padding(.trailing, IndicatorLayout.padding)
        .frame(width: layout.sideWidth, alignment: .trailing)
    }

    private func countdowns(now: Date) -> some View {
        HStack(spacing: IndicatorLayout.spacing) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                countdown(status: CalendarAgenda.status(of: event, now: now, leadTime: leadTime))
                    .opacity(hoveredIndex == nil || hoveredIndex == index ? 1 : 0.45)
            }
        }
        .padding(.leading, IndicatorLayout.padding)
        .frame(width: layout.sideWidth, alignment: .leading)
    }

    private func countdown(status: EventStatus) -> some View {
        let color = Self.color(for: status.phase)
        return Text(CalendarAgenda.countdownText(status.remaining))
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(width: IndicatorLayout.slotWidth, height: IndicatorLayout.capsuleHeight)
            .background(ClockwiseCapsule().stroke(Color.white.opacity(0.14), lineWidth: Self.lineWidth))
            .overlay(
                // What is left of the lead time or of the meeting; it shrinks clockwise.
                ClockwiseCapsule()
                    .trim(from: status.progress, to: 1)
                    .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                    .animation(.linear(duration: 1), value: status.progress)
            )
    }

    /// Name and time of the hovered meeting.
    private func label(for event: CalendarEvent, now: Date) -> some View {
        let status = CalendarAgenda.status(of: event, now: now, leadTime: leadTime)
        let time = "\(event.start.formatted(date: .omitted, time: .shortened))–\(event.end.formatted(date: .omitted, time: .shortened))"
        let phase = status.phase == .ongoing ? "most tart" : "kezdődik"
        return HStack(spacing: 6) {
            Circle()
                .fill(event.color.color)
                .frame(width: 6, height: 6)
            Text(event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(time) · \(phase)")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(Self.color(for: status.phase))
                .lineLimit(1)
                .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .frame(height: IndicatorLayout.labelHeight - 4)
        .frame(maxWidth: .infinity)
    }

    static func color(for phase: EventStatus.Phase) -> Color {
        switch phase {
        case .upcoming: Color(red: 1, green: 0.8, blue: 0.25)
        case .imminent: Color(red: 1, green: 0.3, blue: 0.3)
        case .ongoing: Color(red: 0.45, green: 0.78, blue: 1)
        }
    }
}
