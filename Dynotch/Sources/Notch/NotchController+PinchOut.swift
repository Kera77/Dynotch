import AppKit
import SwiftUI

/// The Home tile under the pointer, for a pinch out (spec N-28). Only one pointer, so one tile.
@MainActor
enum HomeTileHover {
    static var current: (tile: HomeTile, anchor: UnitPoint)?
}

extension NotchController {
    /// A pinch out opens what the pointer is on, as a click would (spec N-28): beside the closed
    /// notch a drop-down's module, a badge's notifications or the notification peek; in the Home
    /// the tile's module. A pinch in afterwards goes back (N-27, HT-40).
    func handlePinchOut(_ event: NSEvent) -> Bool {
        guard let target = pinchOutTarget() else { return false }
        if tileBack.pinch(phase: Self.phase(of: event), magnification: event.magnification) == .outward {
            DiagnosticsLog.append("notch", "opened by pinch: \(target.name)")
            target.open()
            Haptics.perform(.featureSwitch, settings: settings)
        }
        return true
    }

    private struct PinchOutTarget {
        let name: String
        let open: @MainActor () -> Void
    }

    private func pinchOutTarget() -> PinchOutTarget? {
        if model.isExpanded {
            guard model.currentFeature == .home, model.tileOpening == nil, !model.isPreview,
                  model.geometry.rect(for: model.openSize).contains(NSEvent.mouseLocation),
                  let hovered = HomeTileHover.current
            else { return nil }
            return PinchOutTarget(name: "tile \(hovered.tile.rawValue)") { [model] in
                withAnimation(Motion.spring) { model.openTile(hovered.tile, anchor: hovered.anchor) }
            }
        }
        if let id = model.hoveredBadge, let badge = badges.visible.first(where: { $0.id == id }) {
            return PinchOutTarget(name: "badge") { [weak self] in self?.showNotifications(for: badge) }
        }
        if let index = model.hoveredIndicator {
            let items = collapsedRow().items
            guard items.indices.contains(index), let feature = Self.pinchFeature(of: items[index]),
                  settings.isEnabled(feature)
            else { return nil }
            return PinchOutTarget(name: "indicator \(feature.rawValue)") { [weak self] in self?.openPinched(feature) }
        }
        if notifications.peek != nil, model.geometry.notchRect.insetBy(dx: -80, dy: -60).contains(NSEvent.mouseLocation) {
            return PinchOutTarget(name: "peek") { [weak self] in self?.expand(fromEdge: true) }
        }
        return nil
    }

    private func openPinched(_ feature: FeatureID) {
        setHoveredIndicator(nil)
        setHoveredBadge(nil)
        expand(fromEdge: true)
        withAnimation(Self.animation) { model.select(feature, remember: false, exact: true) }
    }

    /// The module a drop-down beside the notch grows into.
    static func pinchFeature(of item: IndicatorItem) -> FeatureID? {
        switch item {
        case .meeting: .calendar
        case .usage: .claudeUsage
        case .working: .claudeChat
        case .battery: .battery
        case .tasks: .reminders
        case .music: .music
        case .stats: .stats
        case .tools: .tools
        case .recording: nil
        }
    }
}
