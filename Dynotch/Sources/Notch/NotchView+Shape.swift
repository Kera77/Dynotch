import SwiftUI

// MARK: - Shape (spec N-11, N-12)

extension NotchView {
    var cornerRadius: CGFloat {
        if model.isExpanded { return model.isPreview ? 18 : 24 }
        if isCapsule { return NotchCorners.radius(notchHeight: geometry.notchSize.height) }
        if hud.display != nil { return 10 }
        if calls.call != nil { return 20 }
        return isTall ? 16 : 10
    }

    /// A notification, a call or a line hanging below makes the closed notch taller.
    private var isTall: Bool {
        notifications.peek != nil || calls.call != nil || labelIndex != nil || shownNotice != nil
    }

    /// Only the closed notch's resting state, one row high, is a capsule (spec N-11): as soon
    /// as anything unfolds below it, it straightens out, and back again.
    var isCapsule: Bool { settings.roundedNotch && !model.isExpanded && !isTall }

    var capsule: NotchCorners.Capsule {
        guard isCapsule else { return NotchCorners.Capsule(width: size.width, shift: 0) }
        return NotchCorners.capsule(
            width: size.width, offset: collapsedOffset, notchWidth: geometry.notchSize.width, radius: cornerRadius,
            onlyWhereShown: settings.roundOnlyWhereShown
        )
    }

    /// The chosen design shows on the open panel and on a notification; the closed notch stays
    /// black like the hardware (spec D-3).
    var showsDesign: Bool {
        model.isExpanded || notifications.peek != nil
    }

    /// Over a full-screen app nothing shows until the pointer reaches the top edge (spec N-12);
    /// a call and the volume or brightness still do.
    var isHiddenForFullScreen: Bool {
        model.isHiddenForFullScreen && !model.isExpanded && calls.call == nil && hud.display == nil
    }

    var shape: UnevenRoundedRectangle {
        guard isCapsule else {
            return UnevenRoundedRectangle(bottomLeadingRadius: cornerRadius, bottomTrailingRadius: cornerRadius, style: .continuous)
        }
        // A side that is not round keeps the resting notch's small corner (spec N-13).
        let outline = capsule
        let leading = outline.roundsLeading ? cornerRadius : 0
        let trailing = outline.roundsTrailing ? cornerRadius : 0
        return UnevenRoundedRectangle(
            topLeadingRadius: leading,
            bottomLeadingRadius: outline.roundsLeading ? cornerRadius : Self.restingRadius,
            bottomTrailingRadius: outline.roundsTrailing ? cornerRadius : Self.restingRadius,
            topTrailingRadius: trailing,
            style: .continuous
        )
    }

    /// The bottom corners of the closed notch when it is not rounded.
    static var restingRadius: CGFloat { 10 }
}
