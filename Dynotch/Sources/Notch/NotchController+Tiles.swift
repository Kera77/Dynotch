import AppKit
import SwiftUI

/// Counts a pinch (in or out) or a swipe down with two fingers, once per gesture (spec HT-12, HT-40, N-28).
struct TileBackGesture {
    enum Pinch: Equatable { case inward, outward }

    /// How far the fingers pinch in or out (magnification adds up below or above zero).
    static let pinchDistance: CGFloat = 0.18
    /// How far the fingers move down, in points.
    static let swipeDistance: CGFloat = 40

    private var pinch: CGFloat = 0
    private var down: CGFloat = 0
    private var sideways: CGFloat = 0
    private var hasFired = false
    /// A swipe that went back: its remaining events neither scroll the Home nor switch modules.
    private var swallowsSwipe = false

    /// The direction once per gesture, when the fingers pinch in or out far enough.
    mutating func pinch(phase: SwipeDetector.Phase, magnification: CGFloat) -> Pinch? {
        if phase == .began { reset() }
        pinch += magnification
        if fire(when: -pinch >= Self.pinchDistance) { return .inward }
        if fire(when: pinch >= Self.pinchDistance) { return .outward }
        return nil
    }

    /// True once, when the fingers move far enough down and more down than sideways.
    mutating func swipe(phase: SwipeDetector.Phase, fingerDown: CGFloat, fingerSideways: CGFloat) -> Bool {
        if phase == .began { reset() }
        down += fingerDown
        sideways += abs(fingerSideways)
        let fired = fire(when: down >= Self.swipeDistance && down > sideways)
        if fired { swallowsSwipe = true }
        return fired
    }

    /// True for the rest of a swipe that went back, momentum included; a new swipe ends it.
    mutating func swallowsRest(began: Bool, inGesture: Bool) -> Bool {
        if began { swallowsSwipe = false }
        return swallowsSwipe && inGesture
    }

    private mutating func fire(when reached: Bool) -> Bool {
        guard reached, !hasFired else { return false }
        hasFired = true
        return true
    }

    private mutating func reset() {
        pinch = 0
        down = 0
        sideways = 0
        hasFired = false
    }
}

extension NotchController {
    /// A pinch over the module opened from a tile, when Pinch is the way back (spec HT-40). The
    /// event tap hands it over whichever app is active, so the pointer must be over the panel.
    func handleTilePinch(_ event: NSEvent) -> Bool {
        if handleEdgePinch(event) || handlePinchOut(event) { return true }
        guard model.isExpanded, model.tileOpening != nil, HomeTileSettings.shared.backGesture == .pinch,
              model.geometry.rect(for: model.openSize).contains(NSEvent.mouseLocation)
        else { return false }
        if tileBack.pinch(phase: Self.phase(of: event), magnification: event.magnification) == .inward { goBackHome(by: "pinch") }
        return true
    }

    /// A pinch over a panel opened from the closed notch's edge closes it, back to the edge (spec N-27).
    private func handleEdgePinch(_ event: NSEvent) -> Bool {
        guard model.isExpanded, model.openedFromEdge, model.tileOpening == nil, !model.isPinned,
              model.geometry.rect(for: model.openSize).contains(NSEvent.mouseLocation)
        else { return false }
        if tileBack.pinch(phase: Self.phase(of: event), magnification: event.magnification) == .inward {
            DiagnosticsLog.append("notch", "closed by pinch (opened from the edge)")
            collapse()
            Haptics.perform(.featureSwitch, settings: settings)
        }
        return true
    }

    /// A downward swipe over the top of the module opened from a tile, when Swipe down is the way
    /// back; nil: not this gesture's place (spec HT-12, HT-40).
    func handleTileSwipeDown(_ event: NSEvent) -> Bool? {
        let inGesture = !event.phase.isEmpty || !event.momentumPhase.isEmpty
        if tileBack.swallowsRest(began: event.phase.contains(.began), inGesture: inGesture) { return true }
        guard model.isExpanded, model.tileOpening != nil, HomeTileSettings.shared.backGesture == .swipeDown,
              tileTopZone.contains(NSEvent.mouseLocation)
        else { return nil }
        let fingerDown = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        let fingerSideways = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        guard event.momentumPhase.isEmpty else { return true }
        if tileBack.swipe(phase: Self.phase(of: event), fingerDown: fingerDown, fingerSideways: fingerSideways) {
            goBackHome(by: "swipe down")
            return true
        }
        // Sideways it still switches modules (spec S-1).
        return abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) ? true : nil
    }

    /// The top row and the ‹ Home row under it.
    private var tileTopZone: CGRect {
        let geometry = model.geometry
        let panel = geometry.rect(for: model.openSize)
        let height = geometry.menuBarHeight + 34
        return CGRect(x: panel.minX, y: panel.maxY - height, width: panel.width, height: height + NotchGeometry.topEdgeTolerance)
    }

    /// The same way back as the ‹ Home button, animation included (spec HT-41).
    private func goBackHome(by gesture: String) {
        DiagnosticsLog.append("home", "back to Home: \(gesture)")
        model.backToHomeAnimated()
        Haptics.perform(.featureSwitch, settings: settings)
    }
}
