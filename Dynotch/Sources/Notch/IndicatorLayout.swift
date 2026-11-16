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

    /// Width of the item's place right of the notch: a countdown capsule, or the usage ring.
    var slotWidth: CGFloat {
        switch self {
        case .meeting: IndicatorLayout.slotWidth
        case .usage: IndicatorLayout.ringSlotWidth
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
    /// The AI usage is a ring without text (spec CL-6).
    static let ringSlotWidth: CGFloat = 26
    static let iconWidth: CGFloat = 24
    static let iconHeight: CGFloat = 22
    static let capsuleHeight: CGFloat = 18
    static let spacing: CGFloat = 6
    static let padding: CGFloat = 8
    /// Height of a meeting's hover label (spec K-8d).
    static let labelHeight: CGFloat = 26
    static let labelWidth: CGFloat = 440
    /// Between two app badges (spec B-4).
    static let badgeSpacing: CGFloat = 8
    /// Room of the thin line between the app badges and the icons.
    static let separatorWidth: CGFloat = 13

    /// Width of each place on the right.
    let slotWidths: [CGFloat]
    /// For each icon on the left (from the notch outwards), the place it stands for.
    let iconSlots: [Int]
    /// Width of each app badge at the far left, from left to right (spec B-4).
    let badgeWidths: [CGFloat]

    /// Number of places on the right.
    var count: Int { slotWidths.count }

    init(count: Int, iconSlots: [Int]? = nil) {
        self.init(slotWidths: Array(repeating: Self.slotWidth, count: max(count, 0)), iconSlots: iconSlots)
    }

    init(slotWidths: [CGFloat], iconSlots: [Int]? = nil, badgeWidths: [CGFloat] = []) {
        self.slotWidths = slotWidths
        self.iconSlots = slotWidths.isEmpty ? [] : (iconSlots ?? [0])
        self.badgeWidths = badgeWidths
    }

    init(items: [IndicatorItem], badges: [BadgeItem] = []) {
        self.init(
            slotWidths: items.map(\.slotWidth), iconSlots: IndicatorItem.iconSlots(for: items),
            badgeWidths: badges.map(\.width)
        )
    }

    var isEmpty: Bool { count < 1 && badgeWidths.isEmpty }

    /// The icons next to the notch, without margins.
    var iconsWidth: CGFloat {
        guard !iconSlots.isEmpty else { return 0 }
        let icons = CGFloat(iconSlots.count)
        return icons * Self.iconWidth + (icons - 1) * Self.spacing
    }

    /// The app badges, without margins.
    var badgesWidth: CGFloat {
        guard !badgeWidths.isEmpty else { return 0 }
        return badgeWidths.reduce(0, +) + CGFloat(badgeWidths.count - 1) * Self.badgeSpacing
    }

    private var hasSeparator: Bool { !iconSlots.isEmpty && !badgeWidths.isEmpty }

    /// Left of the notch: the app badges, a thin line, then the icons.
    var leftWidth: CGFloat {
        let content = iconsWidth + badgesWidth + (hasSeparator ? Self.separatorWidth : 0)
        return content > 0 ? content + 2 * Self.padding : 0
    }

    /// Right of the notch: the capsules.
    var rightWidth: CGFloat {
        guard count >= 1 else { return 0 }
        return slotWidths.reduce(0, +) + CGFloat(count - 1) * Self.spacing + 2 * Self.padding
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

    /// Horizontal centre of place `index`, right of the notch.
    func center(of index: Int, notchRect: CGRect) -> CGFloat {
        let before = slotWidths.prefix(index).reduce(0, +) + CGFloat(index) * Self.spacing
        return notchRect.maxX + Self.padding + before + slotWidths[index] / 2
    }

    /// Horizontal centre of icon `index` (0 = next to the notch).
    func iconCenter(_ index: Int = 0, notchRect: CGRect) -> CGFloat {
        notchRect.minX - Self.padding - Self.iconWidth / 2 - CGFloat(index) * (Self.iconWidth + Self.spacing)
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
            abs(point.x - center(of: $0, notchRect: notchRect)) <= (slotWidths[$0] + Self.spacing) / 2
        }
    }

    /// Horizontal extent of app badge `index` (0 = leftmost).
    func badgeRange(_ index: Int, notchRect: CGRect) -> ClosedRange<CGFloat> {
        let before = badgeWidths.prefix(index).reduce(0, +) + CGFloat(index) * Self.badgeSpacing
        let start = notchRect.minX - leftWidth + Self.padding + before
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
}
