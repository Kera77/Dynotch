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
    /// Badges behind the "+" (spec B-8).
    var hiddenBadges = 0
    var hoveredBadge: String?
    /// Written under the row while no indicator's details are open (spec CN-1).
    var notice: StickyNotice?
    var openBadge: (BadgeItem) -> Void = { _ in }
    var moveBadge: (String, Int) -> Void = { _, _ in }
    var showBadgeNotifications: (BadgeItem) -> Void = { _ in }
    /// Hides an indicator (spec K-8e, CL-6).
    let dismiss: (IndicatorItem) -> Void
    /// Opens the meeting's link (spec K-8g).
    var join: (CalendarEvent) -> Void = { _ in }
    /// Opens the Reminders module (spec R-10).
    var openTasks: () -> Void = {}
    /// Closes the notice under the notch (spec CN-5b).
    var dismissNotice: () -> Void = {}
    var openNotice: () -> Void = {}
    /// Opens the System module from its warning (spec SY-10).
    var openStats: () -> Void = {}
    /// A device's battery history, drawn small in its hover label (spec BT-6).
    var batterySamples: (String) -> [BatterySample] = { _ in [] }
    /// The tasks under the counter's drop-down, and checking one off (spec R-12).
    var taskItems: () -> [ReminderItem] = { [] }
    var completeTask: (ReminderItem) -> Void = { _ in }
    /// A hovered badge's notifications, and opening the app (spec B-10).
    var badgeRows: (BadgeItem) -> [BadgeNotificationRow] = { _ in [] }
    var openBadgeApp: (BadgeItem) -> Void = { _ in }
    var hideBadge: (BadgeItem, BadgeHide.Choice) -> Void = { _, _ in }
    var showsBadgeList = true // off over a notification pop-up (spec E-24)
    /// The cover is hovered: its player drops down, not only the track's name (spec MU-2, MU-4).
    var showsMusicPlayer = false
    /// Stops a screen recording (spec SH-5).
    var stopRecording: () -> Void = {}
    /// The recording's dot is hovered: it grows into a stop button (spec SH-5b).
    var recordingHovered = false
    /// The cover's progress and the stats' numbers (spec MU-3, SY-7).
    var music: MusicService?
    var stats: StatsService?

    static let lineWidth: CGFloat = 2

    private var layout: IndicatorLayout { IndicatorLayout(items: items, badges: badges, overflow: hiddenBadges > 0) }

    private var meetings: [CalendarEvent] {
        items.compactMap { if case .meeting(let event, _) = $0 { event } else { nil } }
    }

    /// Every second only while something counts seconds (a meeting, a recording, a hover label);
    /// otherwise the row is redrawn rarely.
    private var tickInterval: TimeInterval {
        let counts = hoveredIndex != nil || items.contains { item in
            switch item {
            case .meeting, .recording: true
            default: false
            }
        }
        return counts ? 1 : 15
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: tickInterval)) { context in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    leftSide(now: context.date)
                    Color.clear.frame(width: notchSize.width)
                    if !items.isEmpty { capsules(now: context.date) }
                }
                .frame(height: notchSize.height)

                if let hoveredIndex, items.indices.contains(hoveredIndex) {
                    label(for: items[hoveredIndex], now: context.date)
                } else if showsBadgeList, let badge = badges.first(where: { $0.id == hoveredBadge }) {
                    BadgeDropdown(
                        rows: badgeRows(badge), openNotifications: { openBadge(badge) }, openApp: { openBadgeApp(badge) },
                        hide: { hideBadge(badge, $0) }
                    )
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
                if hiddenBadges > 0 {
                    OverflowChip(count: hiddenBadges)
                    if !badges.isEmpty { Color.clear.frame(width: IndicatorLayout.badgeSpacing) }
                }
                if !badges.isEmpty {
                    NotchBadgesView(
                        badges: badges, hoveredID: hoveredBadge, now: now, open: openBadge,
                        showNotifications: showBadgeNotifications, move: moveBadge
                    )
                }
                if !badges.isEmpty || hiddenBadges > 0, !layout.iconSlots.isEmpty {
                    Rectangle()
                        .fill(Color.white.level(0.22))
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
            ForEach(Array(layout.iconSlots.enumerated().reversed()), id: \.offset) { offset, slot in
                icon(for: items[slot], now: now)
                    .frame(width: layout.iconWidths[offset], height: IndicatorLayout.iconHeight)
                    // The meeting's icon never dims (spec K-8l).
                    .opacity(hoveredIndex == nil || hoveredIndex == slot || items[slot].isMeeting ? 1 : 0.45)
            }
        }
    }

    @ViewBuilder
    private func icon(for item: IndicatorItem, now: Date) -> some View {
        switch item {
        case .meeting(let first, _):
            let color = Self.color(for: CalendarAgenda.status(of: first, now: now, leadTime: leadTime).phase)
            Image(systemName: meetings.contains { $0.meetingURL != nil } ? "video.fill" : "calendar")
                .font(.notch(size: 15, weight: .semibold))
                .foregroundStyle(color)
        case .battery(let device, _):
            BatteryDeviceIcon(kind: device.kind, size: 14)
        case .usage, .working:
            // Always white (spec CL-6); the ring carries the level's colour.
            BrandGlyphView(glyph: .claude, size: 16)
        case .music(let glance):
            // Next to the notch on the left (spec MU-2).
            if let music { MusicCoverRing(service: music, glance: glance) }
        case .recording(let since):
            // Left of the notch, as wide as its time (spec SH-5c).
            RecordingSlot(since: since, now: now, isHovered: recordingHovered, stop: stopRecording)
        case .tasks, .stats:
            // Only on the right (spec R-10, SY-7).
            EmptyView()
        }
    }

    private func capsules(now: Date) -> some View {
        HStack(spacing: IndicatorLayout.spacing) {
            // Left-only items (the cover) have no capsule.
            ForEach(Array(items.enumerated()).filter { $0.element.slotWidth > 0 }, id: \.element.id) { index, item in
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
        case .meeting(let event, let unfolded):
            meetingCapsule(item, event: event, unfolded: unfolded, now: now)
        case .usage(let limits, let unfolded):
            let used = limits.map(\.utilization).max() ?? 0
            if unfolded {
                unfoldedUsage(item, limits: limits, ring: usageRing(used: used), now: now)
            } else {
                usageRing(used: used)
            }
        case .working:
            WorkingDots()
                .frame(width: IndicatorLayout.ringSlotWidth, height: LevelRing.size)
        case .battery(let device, let unfolded):
            batteryCapsule(item, device: device, unfolded: unfolded)
        case .tasks(let count):
            TasksCounter(count: count, width: item.slotWidth, open: openTasks)
        case .music:
            EmptyView()
        case .stats:
            if let stats { StatsSlot(service: stats, indicator: stats.indicator) }
        case .recording:
            // Left of the notch (spec SH-5c).
            EmptyView()
        }
    }

    /// How much of the fullest limit is used, as a ring filling clockwise from the top; no text.
    private func usageRing(used: Double) -> some View {
        let color = Self.color(for: UsageLevel(utilization: used))
        return LevelRing(fraction: used / 100, color: color, label: LevelRing.label(for: used / 100))
            .frame(width: IndicatorLayout.ringSlotWidth, height: LevelRing.size)
    }

    /// Not animated: an animation on the outline would also delay the capsule when it moves.
    func capsule(text: String, color: Color, trim: ClosedRange<Double>) -> some View {
        Text(text)
            .font(.notch(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .frame(width: IndicatorLayout.slotWidth, height: IndicatorLayout.capsuleHeight)
            .background(ClockwiseCapsule().stroke(Color.white.level(0.14), lineWidth: Self.lineWidth))
            .overlay(
                ClockwiseCapsule()
                    .trim(from: trim.lowerBound, to: trim.upperBound)
                    .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
            )
    }
}

extension NotchIndicatorView {
    // MARK: - Hover label

    @ViewBuilder
    private func label(for item: IndicatorItem, now: Date) -> some View {
        switch item {
        case .meeting(let event, false):
            meetingLabel(for: event, now: now)
        case .usage(let limits, false):
            usageLabel(for: limits, now: now)
        case .battery(let device, false):
            batteryLabel(device, item: item)
        // Unfolded beside the notch, nothing drops down (spec PV-58, PV-69).
        case .meeting(_, true), .usage(_, true), .battery(_, true):
            EmptyView()
        case .tasks(let count):
            tasksLabel(count, item: item)
        case .music(let glance):
            musicLabel(glance)
        case .recording:
            // Nothing drops down: the dot itself becomes Stop (spec SH-5b).
            EmptyView()
        case .stats:
            statsLabel(item)
        case .working:
            HStack(spacing: 7) {
                Text("Claude is working on your question…")
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: IndicatorLayout.labelHeight - 4)
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
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            // The calendar's own blue, as in the day view (spec K-5c, K-8j).
            Text("\(start)–\(end) · \(phase)")
                .font(.notch(size: 11))
                .monospacedDigit()
                .foregroundStyle(CalendarStyle.eventTime)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 8)
            // Left of the X, for meetings with a link (spec K-8g).
            if event.meetingURL != nil {
                JoinButton(style: .muted) { join(event) }
                    .help("Join the meeting")
                    .accessibilityLabel("Join the meeting")
            }
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
                            .font(.notch(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(Self.usageText(for: limit, now: now))
                            .font(.notch(size: 11))
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
    func dismissButton(for item: IndicatorItem, help: String) -> some View {
        Button {
            dismiss(item)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.notch(size: 13))
                .foregroundStyle(Color.white.level(0.55))
                .contentShape(Circle())
        }
        .buttonStyle(.notch)
        .help(help)
    }

    // MARK: - Colours

    static func color(for phase: EventStatus.Phase) -> Color {
        switch phase {
        case .upcoming: Color.yellow
        case .imminent: Color.red
        case .ongoing: Color(red: 0.45, green: 0.78, blue: 1)
        }
    }

    static func color(for level: UsageLevel) -> Color {
        switch level {
        case .normal: ClaudeUsageView.blue
        case .high: Color.orange
        case .critical: Color.red
        }
    }
}

/// "‹ +3": more badges than fit beside the menu bar; hovering shows them (spec B-8).
private struct OverflowChip: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "chevron.left")
                .font(.notch(size: 8, weight: .bold))
            Text("+\(count)").numericTransition()
                .font(.notch(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(Color.white.level(0.85))
        .frame(width: IndicatorLayout.overflowChipWidth, height: IndicatorLayout.capsuleHeight)
        .background(Capsule(style: .continuous).fill(Color.white.level(0.14)))
        .frame(height: IndicatorLayout.iconHeight)
        .help("\(count) more app\(count == 1 ? "" : "s") with notifications")
    }
}

/// The "swipe up to dismiss" hint: a small, sharp chevron with a narrow angle (spec CN-5).
struct SwipeUpArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}
