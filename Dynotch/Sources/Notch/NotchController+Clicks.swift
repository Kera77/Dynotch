import AppKit

// MARK: - Clicks through the window (spec F-16)

extension NotchController {
    /// The window covers nearly the whole display: unless the pointer is on something of the
    /// closed notch that takes clicks, it lets every click through to the apps below. Before, a
    /// notice or drop-down that went away could leave it catching clicks (spec F-16).
    func settleAfterHover() {
        if !model.isHiddenForFullScreen { updateHoveredIndicator() }
        settleCollapsedMouse(at: NSEvent.mouseLocation)
    }

    func settleCollapsedMouse(at point: CGPoint) {
        guard !model.isExpanded, !callIsShown, !model.isShowingStrip else { return }
        let onRow = model.hoveredIndicator != nil || model.hoveredBadge != nil || model.badgesUnfolded || isOverNotice
        let onPeek = settings.noticesBeside && showsWingsPeek && wingsPeekZone.contains(point)
        if onRow || onPeek {
            panel.ignoresMouseEvents = false
            startHoverTimer()
        } else {
            if !panel.ignoresMouseEvents { panel.ignoresMouseEvents = true }
            stopHoverTimer()
        }
    }
}

// MARK: - Two notifications under the notch (spec E-28)

extension NotchController {
    /// The peek whose card a hover opens: of two rows the one under the pointer, none over the
    /// sticky notice; the top one when the pointer is elsewhere (a shortcut, a click).
    var peekUnderPointer: AppNotification? {
        let point = NSEvent.mouseLocation
        guard hoverZone.contains(point) else { return notifications.peek }
        return notifications.hoveredPeek(depth: model.geometry.notchRect.maxY - point.y, in: model.geometry)
    }
}
