import CoreGraphics

/// Where the (physical or virtual) notch sits on a screen, in global screen coordinates
/// (AppKit: origin bottom-left).
struct NotchGeometry: Equatable, Sendable {
    static let virtualNotchWidth: CGFloat = 185
    static let minimumVirtualNotchHeight: CGFloat = 24
    static let expandedHeight: CGFloat = 200
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

    /// Pointer area that opens the panel (spec N-2): the notch, slightly widened, up to the top edge.
    var hoverZone: CGRect {
        let rect = notchRect
        return CGRect(x: rect.minX - 4, y: rect.minY, width: rect.width + 8, height: rect.height + 2)
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
