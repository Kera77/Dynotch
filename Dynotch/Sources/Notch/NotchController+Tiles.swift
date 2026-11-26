import AppKit
import SwiftUI

/// Counts a pinch in or a swipe down with two fingers, once per gesture (spec HT-12).
struct TileBackGesture {
    /// How far the fingers pinch in (magnification adds up below zero).
    static let pinchDistance: CGFloat = 0.18
    /// How far the fingers move down, in points.
    static let swipeDistance: CGFloat = 40

    private var pinch: CGFloat = 0
    private var down: CGFloat = 0
    private var sideways: CGFloat = 0
    private var hasFired = false

    /// True once, when a pinch in goes far enough.
    mutating func pinch(phase: SwipeDetector.Phase, magnification: CGFloat) -> Bool {
        if phase == .began { reset() }
        pinch += magnification
        return fire(when: -pinch >= Self.pinchDistance)
    }

    /// True once, when the fingers move far enough down and more down than sideways.
    mutating func swipe(phase: SwipeDetector.Phase, fingerDown: CGFloat, fingerSideways: CGFloat) -> Bool {
        if phase == .began { reset() }
        down += fingerDown
        sideways += abs(fingerSideways)
        return fire(when: down >= Self.swipeDistance && down > sideways)
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
    /// A pinch over the module opened from a tile (spec HT-12). Also called by the global monitor:
    /// while another app is active the pinch goes to it, so the pointer must be over the panel (spec HT-36).
    func handleTilePinch(_ event: NSEvent) -> Bool {
        guard model.isExpanded, model.tileOpening != nil,
              model.geometry.rect(for: model.openSize).contains(NSEvent.mouseLocation)
        else { return false }
        if tileBack.pinch(phase: Self.phase(of: event), magnification: event.magnification) { goBackHome(by: "pinch") }
        return true
    }

    /// A downward swipe over the top of the module opened from a tile; nil: not this gesture's place (spec HT-12).
    func handleTileSwipeDown(_ event: NSEvent) -> Bool? {
        guard model.isExpanded, model.tileOpening != nil, tileTopZone.contains(NSEvent.mouseLocation)
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

    /// While another app is active the pinch goes to that app, so a global monitor watches it too (spec HT-36).
    func startTilePinchMonitor() {
        magnifyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.magnify]) { [weak self] event in
            MainActor.assumeIsolated { _ = self?.handleTilePinch(event) }
        }
    }

    func stopTilePinchMonitor() {
        if let magnifyMonitor { NSEvent.removeMonitor(magnifyMonitor) }
        magnifyMonitor = nil
    }

    /// The top row and the ‹ Home row under it.
    private var tileTopZone: CGRect {
        let geometry = model.geometry
        let panel = geometry.rect(for: model.openSize)
        let height = geometry.menuBarHeight + 34
        return CGRect(x: panel.minX, y: panel.maxY - height, width: panel.width, height: height + NotchGeometry.topEdgeTolerance)
    }

    private func goBackHome(by gesture: String) {
        DiagnosticsLog.append("home", "back to Home: \(gesture)")
        withAnimation(Motion.spring) { model.backToHome() }
        Haptics.perform(.featureSwitch, settings: settings)
    }
}
