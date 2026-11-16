import CoreGraphics

/// Where the (physical or virtual) notch sits on a screen, in global screen coordinates
/// (AppKit: origin bottom-left).
struct NotchGeometry: Equatable, Sendable {
    static let virtualNotchWidth: CGFloat = 185
    static let minimumVirtualNotchHeight: CGFloat = 24
    static let expandedHeight: CGFloat = 230
    static let expandedSideWidth: CGFloat = 200
    static let minimumExpandedWidth: CGFloat = 560
    static let largeWidth: CGFloat = 960
    static let largeHeight: CGFloat = 340
    static let minimumMenuBarHeight: CGFloat = 32
    /// Size of the settings content, in its own window and inside the notch alike (spec C-2).
    static let settingsContentSize = CGSize(width: 520, height: 440)
    /// Height of the calendar's day strip, directly below the menu bar.
    static let dayStripHeight: CGFloat = 54
    /// How far the hover zones reach above the screen's top edge. The pointer can sit exactly on
    /// `screenFrame.maxY`, which `CGRect.contains` treats as outside a rect ending there.
    static let topEdgeTolerance: CGFloat = 2

    let screenFrame: CGRect
    let notchSize: CGSize
    let hasPhysicalNotch: Bool

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
                    hasPhysicalNotch: true
                )
            }
        }
        return NotchGeometry(
            screenFrame: screenFrame,
            notchSize: CGSize(width: virtualNotchWidth, height: max(menuBarHeight, minimumVirtualNotchHeight)),
            hasPhysicalNotch: false
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

    /// Normal size of the opened panel.
    var expandedSize: CGSize {
        CGSize(
            width: max(notchSize.width + 2 * Self.expandedSideWidth, Self.minimumExpandedWidth),
            height: Self.expandedHeight
        )
    }

    /// Size of the opened panel in the full calendar view.
    var largeSize: CGSize {
        let width = min(max(Self.largeWidth, expandedSize.width), max(screenFrame.width - 40, expandedSize.width))
        return CGSize(width: width, height: Self.largeHeight)
    }

    /// The closed notch opened a little for a new notification (spec E-3).
    var peekSize: CGSize {
        CGSize(width: max(notchSize.width + 140, 320), height: notchSize.height + 30)
    }

    /// Size of the opened panel while it shows the settings: the settings plus the top row.
    var settingsSize: CGSize {
        CGSize(
            width: max(expandedSize.width, Self.settingsContentSize.width + 40),
            height: menuBarHeight + Self.settingsContentSize.height + 12
        )
    }

    /// Size of the (constant) panel window: big enough for every panel size.
    var windowSize: CGSize {
        CGSize(
            width: max(largeSize.width, settingsSize.width),
            height: max(largeSize.height, settingsSize.height)
        )
    }

    /// The panel showing the AI usage: tall enough for every limit without scrolling (spec CL-3).
    var usageSize: CGSize {
        CGSize(width: expandedSize.width, height: max(Self.expandedHeight, menuBarHeight + 260))
    }

    /// The panel showing a single notification, opened by hovering its peek (spec E-4).
    var notificationSize: CGSize {
        CGSize(width: max(peekSize.width, 440), height: notchSize.height + 124)
    }

    var expandedRect: CGRect {
        rect(for: expandedSize)
    }

    /// Pointer area that opens the panel (spec N-2): the notch, slightly widened, past the top edge.
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
        let panel = expandedRect
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
    func keepOpenZone(for size: CGSize) -> CGRect {
        let rect = rect(for: size)
        return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + Self.topEdgeTolerance)
    }
}
