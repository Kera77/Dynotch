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

    /// The pointer is on the visible notch: the open panel, or a drop-down, notice or
    /// notification of the closed one. Focus does not follow it to the windows below (spec F-19).
    func holdsPointer(_ point: CGPoint) -> Bool {
        if model.isExpanded { return model.geometry.rect(for: model.openSize).contains(point) }
        if hoverZone.contains(point) { return true }
        return !panel.ignoresMouseEvents && (model.hoveredIndicator != nil || model.hoveredBadge != nil || isOverNotice)
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

// MARK: - Pop-ups reaching out of the notch (spec R-23)

extension NotchController {
    /// A pop-up opened from the panel (a popover, a date picker's calendar) reaches out of the
    /// notch: the panel stays while it is on screen. The glass under the panel does not count.
    var hasOpenPopup: Bool {
        panel.childWindows?.contains { $0 !== glassPanel && $0.isVisible } ?? false
    }
}
