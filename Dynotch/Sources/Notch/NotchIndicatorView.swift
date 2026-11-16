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

/// Something shown beside the closed notch: a meeting countdown, or the Claude usage (spec
/// K-7, CL-6).
enum IndicatorItem: Identifiable, Equatable {
    case meeting(CalendarEvent)
    /// All usage limits; the capsule shows the fullest one.
    case usage([UsageLimit])

    var id: String {
        switch self {
        case .meeting(let event): "meeting-\(event.id)"
        case .usage: "claude-usage"
        }
    }

    /// Height of the hover label below the notch.
    var labelHeight: CGFloat {
        switch self {
        case .meeting: IndicatorLayout.labelHeight
        case .usage(let limits): 12 + CGFloat(max(limits.count, 1)) * 20
        }
    }

    /// Meetings first, the usage last (rightmost).
    static func items(meetings: [CalendarEvent], usage: [UsageLimit]?) -> [IndicatorItem] {
        meetings.map(IndicatorItem.meeting) + (usage.map { [.usage($0)] } ?? [])
    }

    /// The slot of each icon left of the notch, from the notch outwards: the meeting icon stands
    /// for the first meeting, the Claude icon for the usage.
    static func iconSlots(for items: [IndicatorItem]) -> [Int] {
        var slots: [Int] = []
        if let meeting = items.firstIndex(where: { if case .meeting = $0 { true } else { false } }) { slots.append(meeting) }
        if let usage = items.firstIndex(where: { if case .usage = $0 { true } else { false } }) { slots.append(usage) }
        return slots
    }
}

/// Where the indicators sit beside the closed notch: icons on the left, capsules on the right.
/// The two sides have their own widths, so the black area is asymmetric (spec K-7). Shared by
/// the view and the hover hit test.
struct IndicatorLayout: Equatable {
    static let slotWidth: CGFloat = 46
    static let iconWidth: CGFloat = 22
    static let capsuleHeight: CGFloat = 18
    static let spacing: CGFloat = 6
    static let padding: CGFloat = 8
    /// Height of a meeting's hover label (spec K-8d).
    static let labelHeight: CGFloat = 26
    static let labelWidth: CGFloat = 440

    /// Number of capsules on the right.
    let count: Int
    /// For each icon on the left (from the notch outwards), the capsule it stands for.
    let iconSlots: [Int]

    init(count: Int, iconSlots: [Int]? = nil) {
        self.count = count
        self.iconSlots = iconSlots ?? (count < 1 ? [] : [0])
    }

    init(items: [IndicatorItem]) {
        self.init(count: items.count, iconSlots: IndicatorItem.iconSlots(for: items))
    }

    var isEmpty: Bool { count < 1 }

    /// Left of the notch: the icons.
    var leftWidth: CGFloat {
        guard !isEmpty, !iconSlots.isEmpty else { return 0 }
        let icons = CGFloat(iconSlots.count)
        return icons * Self.iconWidth + (icons - 1) * Self.spacing + 2 * Self.padding
    }

    /// Right of the notch: the capsules.
    var rightWidth: CGFloat {
        guard !isEmpty else { return 0 }
        return CGFloat(count) * Self.slotWidth + CGFloat(count - 1) * Self.spacing + 2 * Self.padding
    }

    func rowWidth(notch: CGSize) -> CGFloat {
        notch.width + leftWidth + rightWidth
    }

    /// Size of the closed notch with the indicators, and with a hover label of the given height.
    func size(notch: CGSize, labelHeight: CGFloat?) -> CGSize {
        guard !isEmpty else { return notch }
        let width = rowWidth(notch: notch)
        guard let labelHeight else { return CGSize(width: width, height: notch.height) }
        return CGSize(width: max(width, Self.labelWidth), height: notch.height + labelHeight)
    }

    /// How far the black area's centre is right of the notch's centre.
    var horizontalOffset: CGFloat {
        (rightWidth - leftWidth) / 2
    }

    /// The black area in global coordinates (AppKit, origin bottom-left).
    func rect(notchRect: CGRect, labelHeight: CGFloat?) -> CGRect {
        let size = size(notch: notchRect.size, labelHeight: labelHeight)
        let centerX = notchRect.midX + horizontalOffset
        return CGRect(x: centerX - size.width / 2, y: notchRect.maxY - size.height, width: size.width, height: size.height)
    }

    /// Horizontal centre of capsule `index`, right of the notch.
    func center(of index: Int, notchRect: CGRect) -> CGFloat {
        notchRect.maxX + Self.padding + Self.slotWidth / 2 + CGFloat(index) * (Self.slotWidth + Self.spacing)
    }

    /// Horizontal centre of icon `index` (0 = next to the notch).
    func iconCenter(_ index: Int = 0, notchRect: CGRect) -> CGFloat {
        notchRect.minX - Self.padding - Self.iconWidth / 2 - CGFloat(index) * (Self.iconWidth + Self.spacing)
    }

    /// The indicator under a point (global coordinates), if any.
    func slot(at point: CGPoint, notchRect: CGRect) -> Int? {
        guard !isEmpty, point.y >= notchRect.minY, point.y <= notchRect.maxY + NotchGeometry.topEdgeTolerance else {
            return nil
        }
        if point.x < notchRect.minX, point.x >= notchRect.minX - leftWidth {
            let nearest = iconSlots.indices.min {
                abs(point.x - iconCenter($0, notchRect: notchRect)) < abs(point.x - iconCenter($1, notchRect: notchRect))
            }
            return nearest.map { iconSlots[$0] }
        }
        let reach = (Self.slotWidth + Self.spacing) / 2
        return (0..<count).first { abs(point.x - center(of: $0, notchRect: notchRect)) <= reach }
    }
}

/// Shown beside the closed notch (spec K-7…K-9, CL-6): icons on the left; on the right meeting
/// countdowns, whose outline shows the time left and runs down clockwise, and the Claude usage,
/// whose outline fills as the limit is used. The hovered one's details are written below.
struct NotchIndicatorView: View {
    let items: [IndicatorItem]
    let leadTime: TimeInterval
    let notchSize: CGSize
    let hoveredIndex: Int?
    /// Hides an indicator (spec K-8e, CL-6).
    let dismiss: (IndicatorItem) -> Void

    private static let lineWidth: CGFloat = 1.5
    static let claudeColor = Color(red: 0.85, green: 0.47, blue: 0.34)

    private var layout: IndicatorLayout { IndicatorLayout(items: items) }

    private var meetings: [CalendarEvent] {
        items.compactMap { if case .meeting(let event) = $0 { event } else { nil } }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    icons(now: context.date)
                    Color.clear.frame(width: notchSize.width)
                    capsules(now: context.date)
                }
                .frame(height: notchSize.height)

                if let hoveredIndex, items.indices.contains(hoveredIndex) {
                    label(for: items[hoveredIndex], now: context.date)
                }
            }
        }
    }

    // MARK: - Row

    /// Icons from the notch outwards: the meeting icon (camera if any meeting has a link), then
    /// the Claude icon.
    private func icons(now: Date) -> some View {
        HStack(spacing: IndicatorLayout.spacing) {
            ForEach(Array(layout.iconSlots.enumerated().reversed()), id: \.offset) { _, slot in
                icon(for: items[slot], now: now)
                    .frame(width: IndicatorLayout.iconWidth, height: IndicatorLayout.capsuleHeight)
                    .opacity(hoveredIndex == nil || hoveredIndex == slot ? 1 : 0.45)
            }
        }
        .frame(width: layout.leftWidth)
    }

    @ViewBuilder
    private func icon(for item: IndicatorItem, now: Date) -> some View {
        switch item {
        case .meeting(let first):
            let color = Self.color(for: CalendarAgenda.status(of: first, now: now, leadTime: leadTime).phase)
            Image(systemName: meetings.contains { $0.meetingURL != nil } ? "video.fill" : "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        case .usage:
            ClaudeIcon()
        }
    }

    private func capsules(now: Date) -> some View {
        HStack(spacing: IndicatorLayout.spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                capsule(for: item, now: now)
                    .opacity(hoveredIndex == nil || hoveredIndex == index ? 1 : 0.45)
            }
        }
        .padding(.leading, IndicatorLayout.padding)
        .frame(width: layout.rightWidth, alignment: .leading)
    }

    @ViewBuilder
    private func capsule(for item: IndicatorItem, now: Date) -> some View {
        switch item {
        case .meeting(let event):
            let status = CalendarAgenda.status(of: event, now: now, leadTime: leadTime)
            // What is left of the lead time or of the meeting; it shrinks clockwise.
            capsule(text: CalendarAgenda.countdownText(status.remaining), color: Self.color(for: status.phase),
                    trim: status.progress...1)
        case .usage(let limits):
            let peak = limits.max { $0.utilization < $1.utilization }
            let used = peak?.utilization ?? 0
            // How much of the fullest limit is used; it fills clockwise.
            capsule(text: "\(Int(used.rounded()))%", color: Self.color(for: UsageLevel(utilization: used)),
                    trim: 0...(used / 100))
        }
    }

    /// Not animated: an animation on the outline would also delay the capsule when it moves.
    private func capsule(text: String, color: Color, trim: ClosedRange<Double>) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(width: IndicatorLayout.slotWidth, height: IndicatorLayout.capsuleHeight)
            .background(ClockwiseCapsule().stroke(Color.white.opacity(0.14), lineWidth: Self.lineWidth))
            .overlay(
                ClockwiseCapsule()
                    .trim(from: trim.lowerBound, to: trim.upperBound)
                    .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
            )
    }

    // MARK: - Hover label

    @ViewBuilder
    private func label(for item: IndicatorItem, now: Date) -> some View {
        switch item {
        case .meeting(let event):
            meetingLabel(for: event, now: now)
        case .usage(let limits):
            usageLabel(for: limits, now: now)
        }
    }

    /// Name and time of the hovered meeting.
    private func meetingLabel(for event: CalendarEvent, now: Date) -> some View {
        let status = CalendarAgenda.status(of: event, now: now, leadTime: leadTime)
        let start = event.start.formatted(date: .omitted, time: .shortened)
        let end = event.end.formatted(date: .omitted, time: .shortened)
        let phase = status.phase == .ongoing ? "in progress" : "starting"
        return HStack(spacing: 6) {
            Circle()
                .fill(event.color.color)
                .frame(width: 6, height: 6)
            Text(event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("\(start)–\(end) · \(phase)")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(Self.color(for: status.phase))
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 8)
            dismissButton(for: .meeting(event), help: "Hide this countdown")
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Every usage limit: used, left, and when it resets (spec CL-6).
    private func usageLabel(for limits: [UsageLimit], now: Date) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(limits) { limit in
                    HStack(spacing: 6) {
                        Text(limit.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(Self.usageText(for: limit, now: now))
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(Self.color(for: limit.level))
                            .lineLimit(1)
                    }
                    .frame(height: 16)
                }
            }
            dismissButton(for: .usage(limits), help: "Hide until usage reaches the next 10%")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    static func usageText(for limit: UsageLimit, now: Date) -> String {
        let used = Int(limit.utilization.rounded())
        let reset = limit.resetsAt.map { " · resets " + UsageAlerts.resetText($0, now: now) } ?? ""
        return "\(used)% used · \(100 - used)% left\(reset)"
    }

    /// Always at the right edge (spec K-8e).
    private func dismissButton(for item: IndicatorItem, help: String) -> some View {
        Button {
            dismiss(item)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.55))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Colours

    static func color(for phase: EventStatus.Phase) -> Color {
        switch phase {
        case .upcoming: Color(red: 1, green: 0.8, blue: 0.25)
        case .imminent: Color(red: 1, green: 0.3, blue: 0.3)
        case .ongoing: Color(red: 0.45, green: 0.78, blue: 1)
        }
    }

    static func color(for level: UsageLevel) -> Color {
        switch level {
        case .normal: claudeColor
        case .high: Color(red: 1, green: 0.62, blue: 0.1)
        case .critical: Color(red: 1, green: 0.3, blue: 0.3)
        }
    }
}

/// The Claude app's icon if it is installed, otherwise a sparkle in Claude's colour.
private struct ClaudeIcon: View {
    @MainActor private static let appIcon: NSImage? = NSWorkspace.shared
        .urlForApplication(withBundleIdentifier: "com.anthropic.claudefordesktop")
        .map { NSWorkspace.shared.icon(forFile: $0.path) }

    var body: some View {
        if let icon = Self.appIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NotchIndicatorView.claudeColor)
        }
    }
}
