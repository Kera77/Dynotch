import CoreGraphics

/// Where the (physical or virtual) notch sits on a screen, in global screen coordinates
/// (AppKit: origin bottom-left).
struct NotchGeometry: Equatable, Sendable {
    /// Even, so the notch is centred on whole pixels and nothing beside it is blurred.
    static let virtualNotchWidth: CGFloat = 186
    static let minimumVirtualNotchHeight: CGFloat = 24
    static let expandedHeight: CGFloat = 230
    static let expandedSideWidth: CGFloat = 200
    static let minimumExpandedWidth: CGFloat = 560
    static let largeWidth: CGFloat = 960
    static let largeHeight: CGFloat = 340
    static let minimumMenuBarHeight: CGFloat = 32
    /// Size of the settings content, in its own window and inside the notch alike (spec C-2).
    static let settingsContentSize = CGSize(width: 680, height: 440)
    /// Height of the calendar's day strip, directly below the menu bar.
    static let dayStripHeight: CGFloat = 54
    /// How far the hover zones reach above the screen's top edge. The pointer can sit exactly on
    /// `screenFrame.maxY`, which `CGRect.contains` treats as outside a rect ending there.
    static let topEdgeTolerance: CGFloat = 2

    let screenFrame: CGRect
    let notchSize: CGSize
    let hasPhysicalNotch: Bool
    /// The display's own menu bar, from the top of the screen to the top of its visible frame (spec D-26).
    var systemMenuBarHeight: CGFloat = 0

    /// - Parameters:
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top` (0 on screens without a notch).
    ///   - auxiliaryLeftWidth/RightWidth: widths of `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`.
    ///   - menuBarHeight: used for the virtual notch height on screens without a notch.
    static func make(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryLeftWidth: CGFloat?,
        auxiliaryRightWidth: CGFloat?,
        menuBarHeight: CGFloat
    ) -> NotchGeometry {
        if safeAreaTop > 0, let left = auxiliaryLeftWidth, let right = auxiliaryRightWidth {
            let width = screenFrame.width - left - right
            if width > 0 {
                return NotchGeometry(
                    screenFrame: screenFrame,
                    notchSize: CGSize(width: width, height: safeAreaTop),
                    hasPhysicalNotch: true,
                    systemMenuBarHeight: menuBarHeight
                )
            }
        }
        return NotchGeometry(
            screenFrame: screenFrame,
            notchSize: CGSize(width: virtualNotchWidth, height: max(menuBarHeight, minimumVirtualNotchHeight)),
            hasPhysicalNotch: false,
            systemMenuBarHeight: menuBarHeight
        )
    }

    /// The notch itself.
    var notchRect: CGRect {
        rect(for: notchSize)
    }

    /// Height of the panel's top row (feature switcher beside the notch).
    var menuBarHeight: CGFloat {
        max(notchSize.height, Self.minimumMenuBarHeight)
    }

    /// The black of Black over glass: exactly the display's menu bar, the line right under it;
    /// a hidden menu bar (0) leaves the top row (spec D-26).
    var blackRowHeight: CGFloat {
        systemMenuBarHeight > 0 ? min(systemMenuBarHeight, menuBarHeight + 16) : menuBarHeight
    }

    /// Normal size of the opened panel.
    var expandedSize: CGSize {
        CGSize(
            width: max(notchSize.width + 2 * Self.expandedSideWidth, Self.minimumExpandedWidth),
            height: Self.expandedHeight
        )
    }

    /// The Notifications module: the normal panel plus the row of its tab picker (spec UM-8c).
    var notificationsModuleSize: CGSize {
        CGSize(width: expandedSize.width, height: Self.expandedHeight + 110)
    }

    /// The Tools: as tall as the Pomodoro needs under the top row, its picker and a 120 pt ring
    /// with dots and buttons, without an empty band at the bottom (spec TM-18, TM-22).
    var toolsSize: CGSize {
        CGSize(width: expandedSize.width, height: menuBarHeight + Self.toolsContentHeight)
    }

    /// Picker 22 + gap 8 + ring 120 + dots and buttons 61 + bottom margin 12 (spec TM-22).
    static let toolsContentHeight: CGFloat = 223

    /// A large display (e.g. an external monitor): the Wings show more (spec PV-75).
    var isRoomy: Bool { screenFrame.width >= 1800 }

    /// Size of the opened panel in the full calendar view.
    var largeSize: CGSize {
        let width = min(max(Self.largeWidth, expandedSize.width), max(screenFrame.width - 40, expandedSize.width))
        return CGSize(width: width, height: Self.largeHeight)
    }

    /// The closed notch opened a little for a new notification (spec E-3).
    var peekSize: CGSize {
        CGSize(width: max(notchSize.width + 140, 320), height: notchSize.height + 30)
    }

    /// A device notice under the notch: one row like "Claude finished", only wider when the
    /// batteries or quick buttons need it (spec DV-9, DV-15).
    func devicePeekSize(levels: Int, actions: Int) -> CGSize {
        let extra = (levels > 0 ? 80 : 0) + CGFloat(actions) * 70
        return CGSize(
            width: max(notchSize.width + 140, IndicatorLayout.labelWidth + extra),
            height: notchSize.height + IndicatorLayout.labelHeight
        )
    }

    func devicePeekSize(for event: DeviceEvent?) -> CGSize {
        devicePeekSize(levels: event?.levels.count ?? 0, actions: event?.actions.count ?? 0)
    }

    /// The closed notch opened for an incoming call (spec P-1), taller with the message field.
    func callSize(composing: Bool) -> CGSize {
        CGSize(
            width: max(notchSize.width + 200, 400),
            height: notchSize.height + CallView.rowHeight + (composing ? CallView.composeHeight : 0)
        )
    }

    /// DyNotch Wings: the notch widened to both sides at its own height, as far as the wider
    /// side's content needs, at most two thirds of the display (spec PV-4, PV-8).
    func previewSize(side: CGFloat) -> CGSize {
        let wanted = notchSize.width + 2 * max(side, Self.previewMinSide)
        return CGSize(width: max(min(wanted, screenFrame.width * 2 / 3), notchSize.width), height: notchSize.height)
    }

    static let previewMinSide: CGFloat = 120

    /// The Claude chat with a conversation: grows downwards (spec CC-3).
    var chatSize: CGSize {
        CGSize(width: mediumSize.width, height: min(470, settingsSize.height))
    }

    /// Size of the opened panel while it shows the settings: the settings plus the top row.
    var settingsSize: CGSize {
        CGSize(
            width: max(expandedSize.width, Self.settingsContentSize.width + 40),
            height: menuBarHeight + Self.settingsContentSize.height + 12
        )
    }

    /// Size of the (constant) panel window: big enough for every panel size, a resized module
    /// included (spec RS-2).
    var windowSize: CGSize {
        CGSize(
            width: max(largeSize.width, settingsSize.width, maxNotificationSize.width, maxModuleSize.width),
            height: max(
                largeSize.height, settingsSize.height, maxNotificationSize.height, usageSize.height, chatPanelSize.height,
                maxModuleSize.height
            )
        )
    }

    /// The largest a module can be resized to: nearly the display's width, three quarters of its
    /// height (spec RS-2).
    var maxModuleSize: CGSize {
        CGSize(width: max(screenFrame.width - 40, expandedSize.width), height: max(screenFrame.height * 0.75, Self.expandedHeight))
    }

    /// The panel showing the AI usage: tall enough for every limit without scrolling (spec CL-3).
    var usageSize: CGSize {
        CGSize(width: expandedSize.width, height: max(Self.expandedHeight, menuBarHeight + 260))
    }

    static let notificationHeaderHeight: CGFloat = 40
    static let notificationRowHeight: CGFloat = 34
    static let notificationReplyHeight: CGFloat = 46
    static let maxVisibleNotificationRows = 6

    /// The panel with one sender's new messages, opened by hovering the peek (spec E-4): the
    /// sender once, one row per message (scrolling beyond six), plus the reply field.
    func notificationSize(count: Int, hasReply: Bool) -> CGSize {
        let rows = CGFloat(min(max(count, 1), Self.maxVisibleNotificationRows))
        let height = notchSize.height + Self.notificationHeaderHeight + rows * Self.notificationRowHeight + 10
            + (hasReply ? Self.notificationReplyHeight : 0)
        return CGSize(width: max(peekSize.width, 460), height: height)
    }

    /// The tallest notification panel, for the window size.
    var maxNotificationSize: CGSize {
        let size = notificationSize(count: Self.maxVisibleNotificationRows, hasReply: true)
        // A card with long messages grows up to its limit (spec E-23).
        return CGSize(width: size.width, height: max(size.height, NotificationTextLayout.maxStackHeight))
    }

    /// Notes and Reminders: tall like the full calendar, but narrower (spec J-1, R-2).
    var mediumSize: CGSize {
        let width = min(max(720, expandedSize.width), largeSize.width)
        return CGSize(width: width, height: Self.largeHeight)
    }

    var expandedRect: CGRect {
        rect(for: expandedSize)
    }

    /// Pointer area that opens the panel (spec N-2): the notch, slightly widened, past the top edge.
    /// Over a full-screen app the notch is hidden; the pointer at the very top edge, within
    /// the notch's width, opens it (spec N-12).
    var topEdgeZone: CGRect {
        let rect = notchRect
        return CGRect(x: rect.minX, y: screenFrame.maxY - 3, width: rect.width, height: 3 + Self.topEdgeTolerance)
    }

    var hoverZone: CGRect {
        let rect = notchRect
        return CGRect(
            x: rect.minX - 4,
            y: rect.minY,
            width: rect.width + 8,
            height: rect.height + Self.topEdgeTolerance
        )
    }

    /// Pointer area that keeps the normal-size panel open (spec N-3).
    var expandedHoverZone: CGRect {
        keepOpenZone(for: expandedSize)
    }

    /// The calendar day strip in the normal-size panel; horizontal scrolling there scrolls the
    /// days instead of switching features.
    var dayStripZone: CGRect {
        dayStripZone(panel: expandedSize)
    }

    /// The day strip in a panel of the given size, e.g. a resized calendar (spec RS-5).
    func dayStripZone(panel size: CGSize) -> CGRect {
        let panel = rect(for: size)
        return CGRect(
            x: panel.minX,
            y: panel.maxY - menuBarHeight - Self.dayStripHeight,
            width: panel.width,
            height: Self.dayStripHeight
        )
    }

    /// A rect of the given size, centered horizontally and attached to the top of the screen.
    func rect(for size: CGSize) -> CGRect {
        CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Pointer area that keeps a panel of the given size open: the panel, past the top edge.
    /// The Beeper and Google Chat tabs: the chat list beside the conversation (spec BP-1).
    var chatPanelSize: CGSize {
        CGSize(width: min(max(760, expandedSize.width), max(screenFrame.width - 40, expandedSize.width)), height: 420)
    }

    /// The module strip under the notch (spec MS-1): one round icon per module, centred.
    func moduleStripRect(count: Int) -> CGRect {
        let width = CGFloat(count) * Self.stripIconSize + CGFloat(max(count - 1, 0)) * Self.stripSpacing
        return CGRect(
            x: notchRect.midX - width / 2, y: notchRect.minY - Self.stripGap - Self.stripIconSize,
            width: width, height: Self.stripIconSize
        )
    }

    static let stripIconSize: CGFloat = 34
    static let stripSpacing: CGFloat = 8
    static let stripGap: CGFloat = 6

    func keepOpenZone(for size: CGSize) -> CGRect {
        let rect = rect(for: size)
        return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + Self.topEdgeTolerance)
    }
}

/// Corners of the closed notch when it is rounded like the Dynamic Island (spec N-11).
enum NotchCorners {
    /// The resting notch, one row high, gets fully round ends.
    static func radius(notchHeight: CGFloat) -> CGFloat {
        (notchHeight / 2).rounded()
    }

    /// The closed notch's outline in its resting state (spec N-11, N-13).
    struct Capsule: Equatable {
        var width: CGFloat
        /// How far its centre moves from the black area's.
        var shift: CGFloat
        var roundsLeading = true
        var roundsTrailing = true
    }

    /// Round sides reach at least `radius` beyond the notch, so the rounding never cuts into the
    /// physical notch. With `onlyWhereShown`, only a side with something beside the notch is
    /// round; the other keeps the notch's own edge.
    /// - Parameter width: the black area's width, centred on the notch moved by `offset`.
    static func capsule(
        width: CGFloat, offset: CGFloat, notchWidth: CGFloat, radius: CGFloat, onlyWhereShown: Bool = false
    ) -> Capsule {
        let leftContent = (width - notchWidth) / 2 - offset
        let rightContent = (width - notchWidth) / 2 + offset
        let roundsLeft = !onlyWhereShown || leftContent > 0.5
        let roundsRight = !onlyWhereShown || rightContent > 0.5
        let left = roundsLeft ? max(leftContent, radius) : max(leftContent, 0)
        let right = roundsRight ? max(rightContent, radius) : max(rightContent, 0)
        return Capsule(
            width: notchWidth + left + right, shift: (right - left) / 2 - offset,
            roundsLeading: roundsLeft, roundsTrailing: roundsRight
        )
    }
}
