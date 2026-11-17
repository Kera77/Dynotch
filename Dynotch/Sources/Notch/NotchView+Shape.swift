import SwiftUI

// MARK: - Shape (spec N-11, N-12)

extension NotchView {
    var cornerRadius: CGFloat {
        if model.isExpanded { return model.isPreview ? 18 : 24 }
        let isTall = notifications.peek != nil || labelIndex != nil || shownNotice != nil
        if settings.roundedNotch {
            let tall = hud.display == nil && (isTall || calls.call != nil)
            return NotchCorners.radius(notchHeight: geometry.notchSize.height, isTall: tall)
        }
        if hud.display != nil { return 10 }
        if calls.call != nil { return 20 }
        return isTall ? 16 : 10
    }

    /// The closed notch is a capsule when rounded (spec N-11); open, its top straightens out.
    var isCapsule: Bool { settings.roundedNotch && !model.isExpanded }

    var capsule: (width: CGFloat, shift: CGFloat) {
        guard isCapsule else { return (size.width, 0) }
        return NotchCorners.capsule(
            width: size.width, offset: collapsedOffset, notchWidth: geometry.notchSize.width, radius: cornerRadius
        )
    }

    /// Over a full-screen app nothing shows until the pointer reaches the top edge (spec N-12);
    /// a call and the volume or brightness still do.
    var isHiddenForFullScreen: Bool {
        model.isHiddenForFullScreen && !model.isExpanded && calls.call == nil && hud.display == nil
    }

    var shape: UnevenRoundedRectangle {
        let top = isCapsule ? cornerRadius : 0
        return UnevenRoundedRectangle(
            topLeadingRadius: top,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: top,
            style: .continuous
        )
    }
}
