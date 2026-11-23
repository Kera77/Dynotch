import AppKit
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
    /// Unfolded: beside the notch the hovered countdown widens to the right with the name, the
    /// time, Join and an X (spec PV-69).
    case meeting(CalendarEvent, unfolded: Bool = false)
    /// All usage limits; the capsule shows the fullest one. Unfolded: in Wings mode the hovered
    /// ring widens to the right with the reset time and an X (spec PV-58).
    case usage([UsageLimit], unfolded: Bool = false)
    /// Claude is writing an answer in the chat (spec CC-4).
    case working
    /// A device whose battery is low (spec BT-3).
    /// Unfolded: the name, the time left and an X right of the ring (spec PV-69).
    case battery(BatteryDevice, unfolded: Bool = false)
    /// Today's or the open tasks (spec R-10).
    case tasks(TaskCount)
    /// Spotify's cover with the track's progress (spec MU-2).
    case music(MusicIndicator.Glance)
    /// CPU, memory, network speed (this many of them) or a warning (spec SY-7, SY-8).
    case stats(Int)
    /// A screen recording since this time; its details have Stop (spec SH-5).
    case recording(Date)

    var id: String {
        switch self {
        case .meeting(let event, _): "meeting-\(event.id)"
        case .usage: "claude-usage"
        case .working: "claude-working"
        case .battery(let device, _): "battery-\(device.id)"
        case .tasks: "tasks"
        case .music: "music"
        case .stats: "stats"
        case .recording: "recording"
        }
    }

    var isClaude: Bool {
        switch self {
        case .usage, .working: true
        case .meeting, .battery, .tasks, .music, .stats, .recording: false
        }
    }

    /// Hovering these opens their module instead of writing details (spec SY-7). The cover drops
    /// its player down under the row instead (spec MU-2).
    var opensModule: FeatureID? {
        if case .stats = self { .stats } else { nil }
    }

    var isBattery: Bool {
        if case .battery = self { true } else { false }
    }

    /// Width of the item's place right of the notch: a countdown capsule, or the usage ring.
    var slotWidth: CGFloat {
        switch self {
        case .meeting(let event, let unfolded):
            IndicatorLayout.slotWidth + (unfolded ? IndicatorLayout.meetingUnfoldWidth(for: event) : 0)
        case .usage(let limits, let unfolded):
            IndicatorLayout.ringSlotWidth + (unfolded ? IndicatorLayout.usageUnfoldWidth(for: limits) : 0)
        case .working: IndicatorLayout.ringSlotWidth
        case .battery(let device, let unfolded):
            IndicatorLayout.batterySlotWidth + (unfolded ? IndicatorLayout.batteryUnfoldWidth(for: device) : 0)
        case .tasks(let count): count.count > 9 ? IndicatorLayout.tasksSlotWidth + 7 : IndicatorLayout.tasksSlotWidth
        // Only on the left, next to the notch (spec MU-2).
        case .music: 0
        case .stats(let values): IndicatorLayout.statsWidth(values: values)
        // Left of the notch, as wide as its time (spec SH-5c).
        case .recording: 0
        }
    }

    /// Height of the hover label below the notch.
    var labelHeight: CGFloat {
        switch self {
        // Unfolded beside the notch, nothing drops down (spec PV-69).
        case .meeting(_, true), .battery(_, true): 0
        case .meeting, .working, .battery, .stats: IndicatorLayout.labelHeight
        // Nothing drops down; the dot itself becomes Stop (spec SH-5b).
        case .recording: 0
        case .music: IndicatorLayout.musicDropdownHeight
        // The tasks drop down under their header (spec R-12).
        case .tasks(let count):
            IndicatorLayout.labelHeight + (count.isSplit ? IndicatorLayout.taskPickerExtra : 0)
                + CGFloat(min(count.rows, IndicatorLayout.taskRows)) * IndicatorLayout.taskRowHeight + 6
        // Unfolded beside the notch, nothing drops down (spec PV-58).
        case .usage(_, true): 0
        case .usage(let limits, false): 12 + CGFloat(max(limits.count, 1)) * 20
        }
    }

    /// The cover next to the notch, then meetings, the usage, low batteries, the stats, and the
    /// tasks at the far right.
    static func items(
        meetings: [CalendarEvent], usage: [UsageLimit]?, working: Bool = false, lowBatteries: [BatteryDevice] = [],
        tasks: TaskCount? = nil, music: MusicIndicator.Glance? = nil, stats: Int? = nil, recording: Date? = nil
    ) -> [IndicatorItem] {
        (recording.map { [.recording($0)] } ?? [])
            + (music.map { [.music($0)] } ?? []) + meetings.map { .meeting($0) } + (usage.map { [.usage($0)] } ?? [])
            + (working ? [.working] : []) + lowBatteries.map { .battery($0) } + (stats.map { [.stats($0)] } ?? [])
            + (tasks.map { [.tasks($0)] } ?? [])
    }

    /// Beside the notch the hovered AI ring, countdown or low battery unfolds to the right
    /// instead of dropping down (spec PV-58, PV-69).
    static func unfoldingUsage(_ items: [IndicatorItem], hovered: Int?, wings: Bool) -> [IndicatorItem] {
        guard wings, let hovered, items.indices.contains(hovered) else { return items }
        var unfolded = items
        switch items[hovered] {
        case .usage(let limits, false): unfolded[hovered] = .usage(limits, unfolded: true)
        case .meeting(let event, false): unfolded[hovered] = .meeting(event, unfolded: true)
        case .battery(let device, false): unfolded[hovered] = .battery(device, unfolded: true)
        default: return items
        }
        return unfolded
    }

    /// "Resets today 14:30" of the fullest limit, beside the ring (spec PV-58).
    static func usageResetText(_ limits: [UsageLimit], now: Date = Date()) -> String {
        guard let reset = limits.max(by: { $0.utilization < $1.utilization })?.resetsAt else { return "Usage high" }
        return "Resets " + UsageAlerts.resetText(reset, now: now)
    }

    /// The slot of each icon left of the notch, from the notch outwards: the meeting icon stands
    /// for the first meeting, the Claude icon for the usage.
    static func iconSlots(for items: [IndicatorItem]) -> [Int] {
        var slots: [Int] = []
        // The recording's dot and time right next to the notch (spec SH-5c).
        if let recording = items.firstIndex(where: \.isRecording) { slots.append(recording) }
        // The cover sits next to the notch (spec MU-2).
        if let music = items.firstIndex(where: { if case .music = $0 { true } else { false } }) { slots.append(music) }
        if let meeting = items.firstIndex(where: { if case .meeting = $0 { true } else { false } }) { slots.append(meeting) }
        if let claude = items.firstIndex(where: \.isClaude) { slots.append(claude) }
        // Every low device has its own icon.
        slots += items.indices.filter { items[$0].isBattery }
        return slots
    }
}

/// Where the indicators sit beside the closed notch: icons on the left, capsules on the right.
/// The two sides have their own widths, so the black area is asymmetric (spec K-7). Shared by
/// the view and the hover hit test.
struct IndicatorLayout: Equatable {
    static let slotWidth: CGFloat = 46
    /// The AI usage is a ring without text (spec CL-6).
    static let ringSlotWidth: CGFloat = 32

    /// The reset time and the X right of the unfolded ring (spec PV-58).
    static func usageUnfoldWidth(for limits: [UsageLimit], now: Date = Date()) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let text = (IndicatorItem.usageResetText(limits, now: now) as NSString).size(withAttributes: [.font: font]).width
        return ceil(text) + usageUnfoldExtras
    }

    /// Gaps, the X and a little slack around the reset text.
    static let usageUnfoldExtras: CGFloat = 4 + 6 + 15 + 6
    /// "18%" in red (spec BT-3).
    static let batterySlotWidth: CGFloat = 34
    /// The checklist icon and a one-digit count, like the menu bar's (spec R-10).
    static let tasksSlotWidth: CGFloat = 34
    /// "↓12M" or "100%", with room for a warning dot (spec SY-7).
    /// "C 23%", "M 61%", "↓12M" side by side, with room for a warning dot (spec SY-7).
    static func statsWidth(values: Int) -> CGFloat {
        values == 0 ? 26 : CGFloat(values) * 46 + 8
    }
    /// The player under the row (spec MU-2).
    static let musicDropdownHeight: CGFloat = 128
    /// A new track's cover and name (spec MU-4).
    static let musicAnnounceHeight: CGFloat = 42
    static let iconWidth: CGFloat = 24
    static let iconHeight: CGFloat = 22
    static let capsuleHeight: CGFloat = 20
    static let spacing: CGFloat = 6
    static let padding: CGFloat = 8
    /// Height of a meeting's hover label (spec K-8d).
    static let labelHeight: CGFloat = 26
    /// Tasks listed in the counter's drop-down at most; Open shows the rest.
    static let taskRows = 6
    static let taskRowHeight: CGFloat = 22
    /// The list picker makes the tasks' header taller (spec R-17).
    static let taskPickerExtra: CGFloat = 6
    /// A badge's hover list holds this many notifications at most; more than fit scroll (spec B-10e).
    static let badgeRows = 50
    /// The list grows to five senders with a message each, then scrolls (spec B-10e).
    static let badgeDropdownMaxHeight: CGFloat = 8 + 5 * (badgeSenderHeight + badgeMessageHeight)

    /// The hover list's height under the row; an empty list shows one line and Open.
    static func badgeDropdownHeight(rows: [BadgeNotificationRow]) -> CGFloat {
        min(badgeContentHeight(rows: rows), badgeDropdownMaxHeight)
    }

    /// The whole list's height, scrolled or not.
    static func badgeContentHeight(rows: [BadgeNotificationRow]) -> CGFloat {
        let groups = BadgeNotificationRow.bySender(rows, limit: badgeRows)
        guard !groups.isEmpty else { return 34 }
        // A name line per sender, a line per message (spec B-10b).
        return 8 + CGFloat(groups.count) * badgeSenderHeight + CGFloat(groups.reduce(0) { $0 + $1.rows.count }) * badgeMessageHeight
    }

    static let badgeSenderHeight: CGFloat = 20
    static let badgeMessageHeight: CGFloat = 18
    static let labelWidth: CGFloat = 440
    /// Between two app badges (spec B-4).
    static let badgeSpacing: CGFloat = 8
    /// Room of the thin line between the app badges and the icons.
    static let separatorWidth: CGFloat = 14

    /// Width of each place on the right.
    let slotWidths: [CGFloat]
    /// For each icon on the left (from the notch outwards), the place it stands for.
    let iconSlots: [Int]
    /// Each icon's width, in the order of `iconSlots`: the recording's time is wider (spec SH-5c).
    let iconWidths: [CGFloat]
    /// Width of each app badge at the far left, from left to right (spec B-4).
    let badgeWidths: [CGFloat]
    /// The "+" for badges that do not fit beside the menu bar, at the very left (spec B-8).
    let overflowWidth: CGFloat
    static let overflowChipWidth: CGFloat = 34

    /// Number of places on the right.
    var count: Int { slotWidths.count }

    init(count: Int, iconSlots: [Int]? = nil) {
        self.init(slotWidths: Array(repeating: Self.slotWidth, count: max(count, 0)), iconSlots: iconSlots)
    }

    init(
        slotWidths: [CGFloat], iconSlots: [Int]? = nil, iconWidths: [CGFloat]? = nil, badgeWidths: [CGFloat] = [],
        overflow: Bool = false
    ) {
        self.slotWidths = slotWidths
        let slots = slotWidths.isEmpty ? [] : (iconSlots ?? [0])
        self.iconSlots = slots
        self.iconWidths = iconWidths.flatMap { $0.count == slots.count ? $0 : nil }
            ?? Array(repeating: Self.iconWidth, count: slots.count)
        self.badgeWidths = badgeWidths
        self.overflowWidth = overflow ? Self.overflowChipWidth : 0
    }

    init(items: [IndicatorItem], badges: [BadgeItem] = [], overflow: Bool = false) {
        let slots = IndicatorItem.iconSlots(for: items)
        self.init(
            slotWidths: items.map(\.slotWidth), iconSlots: slots, iconWidths: slots.map { items[$0].iconWidth },
            badgeWidths: badges.map(\.width), overflow: overflow
        )
    }

    var isEmpty: Bool { count < 1 && badgeWidths.isEmpty && overflowWidth == 0 }

    /// The "+" and the space after it, before the first badge.
    private var overflowSpan: CGFloat {
        guard overflowWidth > 0 else { return 0 }
        return overflowWidth + (badgeWidths.isEmpty ? 0 : Self.badgeSpacing)
    }

    /// The icons next to the notch, without margins.
    var iconsWidth: CGFloat {
        guard !iconWidths.isEmpty else { return 0 }
        return iconWidths.reduce(0, +) + CGFloat(iconWidths.count - 1) * Self.spacing
    }

    /// The app badges, without margins.
    var badgesWidth: CGFloat {
        guard !badgeWidths.isEmpty else { return 0 }
        return badgeWidths.reduce(0, +) + CGFloat(badgeWidths.count - 1) * Self.badgeSpacing
    }

    private var hasSeparator: Bool { !iconSlots.isEmpty && (!badgeWidths.isEmpty || overflowWidth > 0) }

    /// Left of the notch: the app badges, a thin line, then the icons.
    var leftWidth: CGFloat {
        let content = iconsWidth + overflowSpan + badgesWidth + (hasSeparator ? Self.separatorWidth : 0)
        return content > 0 ? content + 2 * Self.padding : 0
    }

    /// Right of the notch: the capsules.
    var rightWidth: CGFloat {
        // Items shown only on the left (the cover) take no place on the right.
        let shown = slotWidths.filter { $0 > 0 }
        guard !shown.isEmpty else { return 0 }
        return shown.reduce(0, +) + CGFloat(shown.count - 1) * Self.spacing + 2 * Self.padding
    }

    func rowWidth(notch: CGSize) -> CGFloat {
        notch.width + leftWidth + rightWidth
    }

    /// Size of the closed notch with the indicators, and with a hover label of the given height.
    func size(notch: CGSize, labelHeight: CGFloat?) -> CGSize {
        guard !isEmpty else { return notch }
        let width = rowWidth(notch: notch)
        // Nothing below the row (an AI ring unfolded sideways, spec PV-58): only the row.
        guard let labelHeight, labelHeight > 0 else { return CGSize(width: width, height: notch.height) }
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

    /// Horizontal centre of place `index`, right of the notch.
    func center(of index: Int, notchRect: CGRect) -> CGFloat {
        let earlier = slotWidths.prefix(index).filter { $0 > 0 }
        let before = earlier.reduce(0, +) + CGFloat(earlier.count) * Self.spacing
        return notchRect.maxX + Self.padding + before + slotWidths[index] / 2
    }

    /// Horizontal centre of icon `index` (0 = next to the notch).
    func iconCenter(_ index: Int = 0, notchRect: CGRect) -> CGFloat {
        let before = iconWidths.prefix(index).reduce(0, +) + CGFloat(index) * Self.spacing
        let width = iconWidths.indices.contains(index) ? iconWidths[index] : Self.iconWidth
        return notchRect.minX - Self.padding - before - width / 2
    }

    /// The indicator under a point (global coordinates), if any.
    func slot(at point: CGPoint, notchRect: CGRect) -> Int? {
        guard count >= 1, point.y >= notchRect.minY, point.y <= notchRect.maxY + NotchGeometry.topEdgeTolerance else {
            return nil
        }
        if point.x < notchRect.minX {
            let iconZone = iconsWidth + Self.padding + (hasSeparator ? Self.separatorWidth / 2 : Self.padding)
            guard point.x >= notchRect.minX - iconZone else { return nil }
            let nearest = iconSlots.indices.min {
                abs(point.x - iconCenter($0, notchRect: notchRect)) < abs(point.x - iconCenter($1, notchRect: notchRect))
            }
            return nearest.map { iconSlots[$0] }
        }
        return (0..<count).first {
            slotWidths[$0] > 0 && abs(point.x - center(of: $0, notchRect: notchRect)) <= (slotWidths[$0] + Self.spacing) / 2
        }
    }

    /// Horizontal extent of app badge `index` (0 = leftmost).
    func badgeRange(_ index: Int, notchRect: CGRect) -> ClosedRange<CGFloat> {
        let before = badgeWidths.prefix(index).reduce(0, +) + CGFloat(index) * Self.badgeSpacing
        let start = notchRect.minX - leftWidth + Self.padding + overflowSpan + before
        return start...(start + badgeWidths[index])
    }

    /// The app badge under a point (global coordinates), if any.
    func badge(at point: CGPoint, notchRect: CGRect) -> Int? {
        guard point.y >= notchRect.minY, point.y <= notchRect.maxY + NotchGeometry.topEdgeTolerance else { return nil }
        let margin = Self.badgeSpacing / 2
        return badgeWidths.indices.first {
            let range = badgeRange($0, notchRect: notchRect)
            return point.x >= range.lowerBound - margin && point.x <= range.upperBound + margin
        }
    }

    /// Horizontal extent of the "+", if there is one.
    func overflowRange(notchRect: CGRect) -> ClosedRange<CGFloat>? {
        guard overflowWidth > 0 else { return nil }
        let start = notchRect.minX - leftWidth + Self.padding
        return start...(start + overflowWidth)
    }

    /// Everything left of the notch (badges, "+", icons), for hover.
    func leftRange(notchRect: CGRect) -> ClosedRange<CGFloat>? {
        guard leftWidth > 0 else { return nil }
        return (notchRect.minX - leftWidth)...notchRect.minX
    }
}
