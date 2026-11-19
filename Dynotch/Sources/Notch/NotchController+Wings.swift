import AppKit
import SwiftUI

// MARK: - DyNotch Wings gestures (spec PV-5, PV-12, PV-13)

/// The swipes of DyNotch Wings: up on the open panel's top row, and up or down over a
/// notification beside the notch (spec PV-12, PV-13).
struct WingsSwipes {
    var back = VerticalSwipe()
    var peekUp = VerticalSwipe()
    var peekDown = VerticalSwipe()
}

extension NotchController {
    /// A scroll over the open panel that the wings take: nil when it is not theirs.
    func handleWingsScroll(_ event: NSEvent) -> Bool? {
        if model.isPreview { return handlePreviewScroll(event) }
        return handleBackToWings(event) ? true : nil
    }

    /// Over the wings: a two-finger swipe down opens the panel fully (spec PV-5); left or right
    /// switches to the next or previous module, round the end (spec PV-12).
    func handlePreviewScroll(_ event: NSEvent) -> Bool {
        let phase = Self.phase(of: event)
        let fingerDown = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        if previewSwipe.handle(phase: phase, fingerUp: fingerDown, deltaX: event.scrollingDeltaX) {
            openFully()
            return true
        }
        // Not while files are dropped on the wings.
        guard !model.isShowingDropZone else { return true }
        let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        if let direction = swipe.handle(
            phase: phase, isMomentum: !event.momentumPhase.isEmpty, fingerDeltaX: fingerDeltaX, deltaY: event.scrollingDeltaY
        ) {
            withAnimation(Self.animation) { model.stepWings(direction) }
            Haptics.perform(.featureSwitch, settings: settings)
        }
        return true
    }

    /// A swipe up over the open panel's top row folds it back into the wings (spec PV-12). Only
    /// the top row, so the lists below keep scrolling.
    func handleBackToWings(_ event: NSEvent) -> Bool {
        guard settings.hoverPreview, model.isExpanded, !model.isPreview, !model.isShowingNotifications,
              !model.isShowingOverlayPage, !model.isShowingSettings, wingsTopRow.contains(NSEvent.mouseLocation)
        else { return false }
        let fingerUp = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
        guard wingsSwipes.back.handle(phase: Self.phase(of: event), fingerUp: fingerUp, deltaX: event.scrollingDeltaX) else {
            return false
        }
        withAnimation(Self.animation) { startPreview() }
        return true
    }

    /// The open panel's top row: the notch's height across the whole panel.
    private var wingsTopRow: CGRect {
        let geometry = model.geometry
        let panel = geometry.rect(for: model.openSize)
        return CGRect(
            x: panel.minX, y: panel.maxY - geometry.menuBarHeight,
            width: panel.width, height: geometry.menuBarHeight + NotchGeometry.topEdgeTolerance
        )
    }

    /// Over a notification beside the closed notch: a swipe up puts it away, a swipe down opens
    /// it (spec PV-13).
    func handleWingsPeekScroll(_ event: NSEvent) -> Bool {
        guard settings.hoverPreview, notifications.peek != nil, !model.isExpanded, !callIsShown else { return false }
        guard wingsPeekZone.contains(NSEvent.mouseLocation) else { return false }
        let phase = Self.phase(of: event)
        let fingerUp = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
        let swipedUp = wingsSwipes.peekUp.handle(phase: phase, fingerUp: fingerUp, deltaX: event.scrollingDeltaX)
        let swipedDown = wingsSwipes.peekDown.handle(phase: phase, fingerUp: -fingerUp, deltaX: event.scrollingDeltaX)
        if swipedUp {
            foldPeekAway { notifications.clearPeek() }
        } else if swipedDown {
            expand()
        }
        return true
    }
}

// MARK: - Stepping through the modules in the wings (spec PV-12)

extension NotchViewModel {
    /// The next or previous module, the first after the last and back; the wings stay.
    func stepWings(_ direction: NavigationDirection) {
        let list = settings.listedFeatures
        let current = settings.hostFeature(of: currentFeature)
        let target = FeatureID.neighbor(of: current, in: list, direction: direction)
            ?? (direction == .next ? list.first : list.last)
        guard let target, target != current else { return }
        select(target)
        // The new module's wings fit its own content (spec PV-40).
        wings = WingsState()
        setPreview(true)
    }
}

// MARK: - Putting a notice beside the notch away (spec PV-47, PV-48)

extension NotchController {
    /// How long the notice takes to swim into the notch.
    static let peekFoldDuration: TimeInterval = 0.16

    /// A small notice stands beside the closed notch in Wings mode.
    var showsWingsPeek: Bool {
        notifications.peek != nil || devices.current != nil
            || (notices.notice != nil && calendar.announcement == nil && model.hoveredIndicator == nil)
    }

    /// The notice swims into the notch and the shape draws in to the notch; only then do the
    /// module's wings (pointer on the notch) or the closed notch's own items swim out (spec PV-48).
    func foldPeekAway(_ dismiss: () -> Void) {
        guard settings.hoverPreview, !model.isExpanded, !AppleStyle.reducesMotion else {
            withAnimation(NotchView.quickAnimation, dismiss)
            return
        }
        withAnimation(.easeIn(duration: Self.peekFoldDuration)) {
            model.setGathered(true)
            dismiss()
        }
        peekFoldTask?.cancel()
        peekFoldTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.peekFoldDuration + 0.03))
            guard let self, !Task.isCancelled else { return }
            self.peekFoldTask = nil
            self.unfoldAfterPeek()
        }
    }

    private func unfoldAfterPeek() {
        guard model.isGathered else { return }
        if !model.isExpanded, !callIsShown, opens(at: NSEvent.mouseLocation) {
            model.setGathered(false)
            hideStrip()
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
            expand(preview: true, smart: true)
        } else {
            withAnimation(Self.unfoldAnimation) { model.setGathered(false) }
        }
    }
}

// MARK: - Keeping the open panel (spec N-4, PV-54)

extension NotchController {
    var keepOpenZone: CGRect {
        var zone = reachingDown(model.geometry.keepOpenZone(for: model.openSize).offsetBy(dx: model.openOffset, dy: 0))
        // An open clipboard item keeps the wings for its two seconds a little below the notch too (spec PV-54).
        if model.isPreview, model.wings.hoveredClip != nil {
            zone = CGRect(x: zone.minX, y: zone.minY - Self.clipHoldBand, width: zone.width, height: zone.height + Self.clipHoldBand)
        }
        return showsPreviewStrip ? zone.union(stripArea) : zone
    }

    /// How far below the wings an open clipboard item still keeps them (spec PV-54).
    static let clipHoldBand: CGFloat = 40
}
