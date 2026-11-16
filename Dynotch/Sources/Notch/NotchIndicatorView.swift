import SwiftUI

/// Shown beside the closed notch (spec K-7…K-9, CL-6): icons on the left; on the right meeting
/// countdowns, whose outline shows the time left and runs down clockwise, and the Claude usage,
/// whose outline fills as the limit is used. The hovered one's details are written below.
struct NotchIndicatorView: View {
    let items: [IndicatorItem]
    let leadTime: TimeInterval
    let notchSize: CGSize
    let hoveredIndex: Int?
    /// Apps with unread notifications, at the far left (spec B-4).
    var badges: [BadgeItem] = []
    var hoveredBadge: String?
    /// Written under the row while no indicator's details are open (spec CN-1).
    var notice: StickyNotice?
    var openBadge: (BadgeItem) -> Void = { _ in }
    var moveBadge: (String, Int) -> Void = { _, _ in }
    /// Hides an indicator (spec K-8e, CL-6).
    let dismiss: (IndicatorItem) -> Void

    private static let lineWidth: CGFloat = 1.5

    private var layout: IndicatorLayout { IndicatorLayout(items: items, badges: badges) }

    private var meetings: [CalendarEvent] {
        items.compactMap { if case .meeting(let event) = $0 { event } else { nil } }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    leftSide(now: context.date)
                    Color.clear.frame(width: notchSize.width)
                    if !items.isEmpty { capsules(now: context.date) }
                }
                .frame(height: notchSize.height)

                if let hoveredIndex, items.indices.contains(hoveredIndex) {
                    label(for: items[hoveredIndex], now: context.date)
                } else if let notice {
                    noticeLabel(notice)
                }
            }
        }
    }

    // MARK: - Row

    /// From the left: the app badges, a thin line, then the icons (spec B-4).
    @ViewBuilder
    private func leftSide(now: Date) -> some View {
        if layout.leftWidth > 0 {
            HStack(spacing: 0) {
                if !badges.isEmpty {
                    NotchBadgesView(badges: badges, hoveredID: hoveredBadge, now: now, open: openBadge, move: moveBadge)
                }
                if !badges.isEmpty, !layout.iconSlots.isEmpty {
                    Rectangle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 1, height: 12)
                        .frame(width: IndicatorLayout.separatorWidth)
                }
                if !layout.iconSlots.isEmpty { icons(now: now) }
            }
            .frame(width: layout.leftWidth)
        }
    }

    /// Icons from the notch outwards: the meeting icon (camera if any meeting has a link), then
    /// the Claude icon.
    private func icons(now: Date) -> some View {
        HStack(spacing: IndicatorLayout.spacing) {
            ForEach(Array(layout.iconSlots.enumerated().reversed()), id: \.offset) { _, slot in
                icon(for: items[slot], now: now)
                    .frame(width: IndicatorLayout.iconWidth, height: IndicatorLayout.iconHeight)
                    .opacity(hoveredIndex == nil || hoveredIndex == slot ? 1 : 0.45)
            }
        }
    }

    @ViewBuilder
    private func icon(for item: IndicatorItem, now: Date) -> some View {
        switch item {
        case .meeting(let first):
            let color = Self.color(for: CalendarAgenda.status(of: first, now: now, leadTime: leadTime).phase)
            Image(systemName: meetings.contains { $0.meetingURL != nil } ? "video.fill" : "calendar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
        case .usage:
            // Always white (spec CL-6); the ring carries the level's colour.
            BrandGlyphView(glyph: .claude, size: 16)
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
            let used = limits.map(\.utilization).max() ?? 0
            usageRing(used: used)
        }
    }

    /// How much of the fullest limit is used, as a ring filling clockwise from the top; no text.
    private func usageRing(used: Double) -> some View {
        let color = Self.color(for: UsageLevel(utilization: used))
        return LevelRing(fraction: used / 100, color: color, label: LevelRing.label(for: used / 100))
            .frame(width: IndicatorLayout.ringSlotWidth, height: LevelRing.size)
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

    /// E.g. Claude finished a task: stays until swiped up.
    private func noticeLabel(_ notice: StickyNotice) -> some View {
        HStack(spacing: 7) {
            BrandGlyphView(glyph: .claude, size: 14)
            Text(notice.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text([notice.detail, notice.date.formatted(date: .omitted, time: .shortened)].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "chevron.compact.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.4))
                .help("Swipe up with two fingers to dismiss")
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        case .normal: ClaudeUsageView.blue
        case .high: Color(red: 1, green: 0.62, blue: 0.1)
        case .critical: Color(red: 1, green: 0.3, blue: 0.3)
        }
    }
}
