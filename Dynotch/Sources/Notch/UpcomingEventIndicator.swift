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

/// Where the countdowns sit beside the closed notch: one icon on the left, the countdown
/// capsules on the right. The two sides have their own widths, so the black area is asymmetric
/// (spec K-7). Shared by the view and the hover hit test.
struct IndicatorLayout: Equatable {
    static let slotWidth: CGFloat = 46
    static let iconWidth: CGFloat = 22
    static let capsuleHeight: CGFloat = 18
    static let spacing: CGFloat = 6
    static let padding: CGFloat = 8
    /// Extra height for the meeting name shown on hover (spec K-8d).
    static let labelHeight: CGFloat = 26
    static let labelWidth: CGFloat = 440

    /// Number of countdowns.
    let count: Int

    var isEmpty: Bool { count < 1 }

    /// Left of the notch: just the icon.
    var leftWidth: CGFloat {
        isEmpty ? 0 : Self.iconWidth + 2 * Self.padding
    }

    /// Right of the notch: the countdowns.
    var rightWidth: CGFloat {
        guard !isEmpty else { return 0 }
        return CGFloat(count) * Self.slotWidth + CGFloat(count - 1) * Self.spacing + 2 * Self.padding
    }

    /// Width of the row: icon, notch, countdowns.
    func rowWidth(notch: CGSize) -> CGFloat {
        notch.width + leftWidth + rightWidth
    }

    /// Size of the closed notch with the countdowns, and with the hover label.
    func size(notch: CGSize, showsLabel: Bool) -> CGSize {
        guard !isEmpty else { return notch }
        let width = rowWidth(notch: notch)
        guard showsLabel else { return CGSize(width: width, height: notch.height) }
        return CGSize(width: max(width, Self.labelWidth), height: notch.height + Self.labelHeight)
    }

    /// How far the black area's centre is right of the notch's centre.
    var horizontalOffset: CGFloat {
        (rightWidth - leftWidth) / 2
    }

    /// The black area in global coordinates (AppKit, origin bottom-left).
    func rect(notchRect: CGRect, showsLabel: Bool) -> CGRect {
        let size = size(notch: notchRect.size, showsLabel: showsLabel)
        let centerX = notchRect.midX + horizontalOffset
        return CGRect(x: centerX - size.width / 2, y: notchRect.maxY - size.height, width: size.width, height: size.height)
    }

    /// Horizontal centre of countdown `index`, right of the notch.
    func center(of index: Int, notchRect: CGRect) -> CGFloat {
        notchRect.maxX + Self.padding + Self.slotWidth / 2 + CGFloat(index) * (Self.slotWidth + Self.spacing)
    }

    /// Horizontal centre of the single icon left of the notch.
    func iconCenter(notchRect: CGRect) -> CGFloat {
        notchRect.minX - leftWidth / 2
    }

    /// The countdown under a point (global coordinates), if any. The icon stands for the first.
    func slot(at point: CGPoint, notchRect: CGRect) -> Int? {
        guard !isEmpty, point.y >= notchRect.minY, point.y <= notchRect.maxY + NotchGeometry.topEdgeTolerance else {
            return nil
        }
        if point.x < notchRect.minX, point.x >= notchRect.minX - leftWidth { return 0 }
        let reach = (Self.slotWidth + Self.spacing) / 2
        return (0..<count).first { abs(point.x - center(of: $0, notchRect: notchRect)) <= reach }
    }
}

/// Shown beside the closed notch before and during events (spec K-7…K-9): an icon on the left,
/// countdowns on the right inside capsules whose outline shows the time left and runs down
/// clockwise. The hovered one's name is written below the notch.
struct UpcomingEventIndicator: View {
    let events: [CalendarEvent]
    let leadTime: TimeInterval
    let notchSize: CGSize
    let hoveredIndex: Int?
    /// Hides a countdown (spec K-8e).
    let dismiss: (CalendarEvent) -> Void

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

    /// One icon on the left, next to the notch: a camera if any of the events has a meeting
    /// link, otherwise a calendar, in the colour of the first event's phase.
    private func icons(now: Date) -> some View {
        let first = events.first
        let color = first.map { Self.color(for: CalendarAgenda.status(of: $0, now: now, leadTime: leadTime).phase) } ?? .white
        return Image(systemName: events.contains { $0.meetingURL != nil } ? "video.fill" : "calendar")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: IndicatorLayout.iconWidth, height: IndicatorLayout.capsuleHeight)
            .frame(width: layout.leftWidth)
    }

    private func countdowns(now: Date) -> some View {
        HStack(spacing: IndicatorLayout.spacing) {
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                countdown(status: CalendarAgenda.status(of: event, now: now, leadTime: leadTime))
                    .opacity(hoveredIndex == nil || hoveredIndex == index ? 1 : 0.45)
            }
        }
        .padding(.leading, IndicatorLayout.padding)
        .frame(width: layout.rightWidth, alignment: .leading)
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
            Button {
                dismiss(event)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Visszaszámláló elrejtése")
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
