import SwiftUI

// MARK: - Shape (spec N-11, N-12)

extension NotchView {
    var cornerRadius: CGFloat {
        if model.isExpanded, model.isPreview {
            return settings.roundedNotch ? NotchCorners.radius(notchHeight: geometry.notchSize.height) : 10
        }
        if model.isExpanded { return 24 }
        if isCapsule { return NotchCorners.radius(notchHeight: geometry.notchSize.height) }
        if hud.display != nil { return 10 }
        if calls.call != nil { return 20 }
        return isTall ? 16 : 10
    }

    /// A notification, a call or a line hanging below makes the closed notch taller.
    private var isTall: Bool {
        // In Wings mode the small notices stay at the notch's height beside it (spec PV-13, PV-37).
        if wingsPeek != nil { return false }
        return (notifications.peek != nil && !settings.noticesBeside)
            || devices.current != nil || calls.call != nil || shownNotice != nil
            // An AI ring unfolded sideways (spec PV-58) or the recording's Stop drop nothing down.
            || labelIndex.map { labelHeight(of: $0) > 0 } == true
    }

    /// Only the closed notch's resting state, one row high, is a capsule (spec N-11): as soon
    /// as anything unfolds below it, it straightens out, and back again.
    var isCapsule: Bool { settings.roundedNotch && !model.isExpanded && !isTall }

    /// On a display without a notch, a capsule floating below the top edge (spec D-7).
    var isPill: Bool { settings.externalStyle == .pill && !geometry.hasPhysicalNotch }

    /// The modules the strip shows (spec MS-5).
    var stripFeatures: [FeatureID] { ModuleStripChoice.features(from: settings.listedFeatures) }

    /// The strip under the closed notch, or under the preview (spec MS-1, PV-6).
    var showsStrip: Bool {
        if model.isExpanded {
            return model.isPreview && !model.isShowingDropZone && settings.moduleStrip && stripFeatures.count > 1
        }
        return model.isShowingStrip
    }

    /// The gap between a pill and the top edge, and between it and the menu bar's bottom.
    static var pillGap: CGFloat { 3 }

    /// A resting pill sits in the middle of the menu bar, with the same gap above and below: it
    /// is two gaps shorter than the notch row, its content centred (spec D-7).
    var pillTrim: CGFloat { isPill && !model.isExpanded && !isTall ? 2 * Self.pillGap : 0 }

    var capsule: NotchCorners.Capsule {
        guard isCapsule, !isPill else { return NotchCorners.Capsule(width: size.width, shift: 0) }
        return NotchCorners.capsule(
            width: size.width, offset: collapsedOffset, notchWidth: geometry.notchSize.width, radius: cornerRadius,
            onlyWhereShown: settings.roundOnlyWhereShown
        )
    }

    /// The chosen design shows on the open panel and on a notification; the closed notch stays
    /// black like the hardware (spec D-3).
    var showsDesign: Bool {
        // Only the fully opened notch: notifications, device notices and the preview stay black.
        // The tasks counter's drop-down is a small panel of its own and takes the design too (spec R-17).
        (model.isExpanded && !model.isPreview) || showsTasksDropDown
    }

    /// The tasks counter's drop-down is open under the closed notch (spec R-17).
    private var showsTasksDropDown: Bool {
        guard !model.isExpanded, let index = labelIndex, indicatorItems.indices.contains(index) else { return false }
        if case .tasks = indicatorItems[index] { return true }
        return false
    }

    /// A pill one row high, with or without the rounded-notch setting.
    private var isRestingPill: Bool {
        !model.isExpanded && !isTall
    }

    /// Over a full-screen app nothing shows until the pointer reaches the top edge (spec N-12);
    /// a call and the volume or brightness still do.
    var isHiddenForFullScreen: Bool {
        model.isHiddenForFullScreen && !model.isExpanded && calls.call == nil && hud.display == nil
    }

    var shape: UnevenRoundedRectangle {
        if isPill {
            // Round all round: fully at rest, softer when taller; open, the top corners stay small
            // so the top row is not cut at its ends.
            let radius = isCapsule || isRestingPill ? (size.height - pillTrim) / 2 : cornerRadius
            let top = model.isExpanded ? min(radius, 12) : radius
            return UnevenRoundedRectangle(
                topLeadingRadius: top, bottomLeadingRadius: radius, bottomTrailingRadius: radius, topTrailingRadius: top,
                style: .continuous
            )
        }
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

// MARK: - Design (spec D-1, D-14)

extension NotchView {
    var designBackground: some View {
        designFill.opacity(glassOpacity)
    }

    private var designFill: some View {
        DesignBackground(
            design: settings.design, shape: shape, isOpen: showsDesign, layer: layer, openOpacity: settings.panelOpacity,
            refined: settings.refinedDesign, topRow: geometry.menuBarHeight,
            glassTint: wallpaperTone.tint(for: geometry.screenFrame), glassAccent: settings.glassAccent
        )
    }

    /// Lifts the open panel off the windows below (spec D-14a). Drawn in the glass window, which
    /// lets every click through: in the content window it would catch clicks meant for other apps.
    @ViewBuilder var designShadow: some View {
        // Always there and faded, so it grows with the panel instead of standing at the final
        // size before the module has opened into it (spec PV-49).
        if layer == .glass, settings.refinedDesign {
            OuterShadow(shape: shape)
                .opacity(showsDesign ? 1 : 0)
                .animation(showsDesign ? shadowFadeIn : .easeIn(duration: 0.1), value: showsDesign)
                .opacity(glassOpacity)
        }
    }

    /// The glass window's design is hidden while the switcher moves (spec AS-18).
    var glassOpacity: Double { layer == .glass && model.hidesGlass ? 0 : 1 }

    /// The window switcher drops down from a notch that may stand off-centre: its shadow comes
    /// only once it is in place, so no dark ghost slides in from the side (spec AS-17).
    private var shadowFadeIn: Animation {
        model.isShowingSwitcher
            ? .easeOut(duration: NotchController.glassFade).delay(NotchController.glassWait)
            : .easeOut(duration: 0.2).delay(0.12)
    }
}
