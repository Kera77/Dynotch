import CoreGraphics

/// Where the (physical or virtual) notch sits on a screen, in global screen coordinates
/// (AppKit: origin bottom-left).
struct NotchGeometry: Equatable, Sendable {
    static let virtualNotchWidth: CGFloat = 185
    static let minimumVirtualNotchHeight: CGFloat = 24
    static let expandedHeight: CGFloat = 230
    static let expandedSideWidth: CGFloat = 200
    static let minimumExpandedWidth: CGFloat = 560

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
        topCenteredRect(size: notchSize)
    }

    var expandedSize: CGSize {
        CGSize(
            width: max(notchSize.width + 2 * Self.expandedSideWidth, Self.minimumExpandedWidth),
            height: Self.expandedHeight
        )
    }

    /// The opened panel; also the panel window's frame.
    var expandedRect: CGRect {
        topCenteredRect(size: expandedSize)
    }

    /// How far the hover zones reach above the screen's top edge. The pointer can sit exactly on
    /// `screenFrame.maxY`, which `CGRect.contains` treats as outside a rect ending there.
    static let topEdgeTolerance: CGFloat = 2

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

    /// Pointer area that keeps the opened panel open (spec N-3): the panel, past the top edge.
    var expandedHoverZone: CGRect {
        let rect = expandedRect
        return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + Self.topEdgeTolerance)
    }

    private func topCenteredRect(size: CGSize) -> CGRect {
        CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
