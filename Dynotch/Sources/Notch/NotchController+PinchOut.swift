import AppKit
import SwiftUI

/// What each display's panel opened from beside the closed notch ("i" + indicator id, "b" + badge
/// id), and the drop-down a pinch brought back, held until the pointer moves (spec N-29).
@MainActor
enum EdgeReturn {
    static var origins: [ObjectIdentifier: (id: String, at: Date)] = [:]
    static var hold: (point: CGPoint, until: Date)?
}

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
            // Opening the panel gives its own tap; only a tile in the open Home needs one (spec N-30).
            if !target.opensPanel { Haptics.perform(.featureSwitch, settings: settings) }
        }
        return true
    }

    private struct PinchOutTarget {
        let name: String
        /// Opens the panel, whose opening already taps the trackpad (spec N-30).
        var opensPanel = true
        let open: @MainActor () -> Void
    }

    private func pinchOutTarget() -> PinchOutTarget? {
        if model.isExpanded {
            guard model.currentFeature == .home, model.tileOpening == nil, !model.isPreview,
                  model.geometry.rect(for: model.openSize).contains(NSEvent.mouseLocation),
                  let hovered = HomeTileHover.current
            else { return nil }
            return PinchOutTarget(name: "tile \(hovered.tile.rawValue)", opensPanel: false) { [model] in
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
        noteEdgeOrigin()
        setHoveredIndicator(nil)
        setHoveredBadge(nil)
        expand(fromEdge: true)
        withAnimation(Self.animation) {
            if feature == .notifications { model.notificationsTab = .teams }
            model.select(feature, remember: false, exact: true)
        }
    }

    /// Remembers the drop-down or badge under the pointer, for the pinch back (spec N-29). While
    /// opening, one noted just before (its caller cleared the hover first) stays; else it is forgotten.
    /// True when the pointer is on a badge or a drop-down.
    @discardableResult
    func noteEdgeOrigin(opening: Bool = false, badge: String? = nil) -> Bool {
        let key = ObjectIdentifier(self)
        var found = badge.map { "b" + $0 } ?? model.hoveredBadge.map { "b" + $0 }
        if found == nil, let index = model.hoveredIndicator {
            let items = collapsedRow().items
            if items.indices.contains(index) { found = "i" + items[index].id }
        }
        if let found {
            EdgeReturn.origins[key] = (found, Date())
        } else if opening, let noted = EdgeReturn.origins[key], Date().timeIntervalSince(noted.at) > 0.5 {
            EdgeReturn.origins[key] = nil
        }
        return model.hoveredIndicator != nil || model.hoveredBadge != nil
    }

    /// After the pinch closed the panel: the drop-down it opened from drops down again, as if
    /// the pointer were on it, until the pointer moves (spec N-29). The origin, nil: nothing to bring back.
    func restoreEdgeHover() -> String? {
        guard let origin = EdgeReturn.origins.removeValue(forKey: ObjectIdentifier(self))?.id else { return nil }
        let id = String(origin.dropFirst())
        let row = collapsedRow()
        if origin.hasPrefix("b") {
            guard row.fit.shown.contains(where: { $0.id == id }) else { return nil }
            setHoveredBadge(id)
        } else {
            guard let index = row.items.firstIndex(where: { $0.id == id }) else { return nil }
            // The stats without a warning have no drop-down: hovering them opens the module (spec SY-7).
            if row.items[index].opensModule != nil, stats.indicator.warnings.isEmpty { return nil }
            setHoveredIndicator(index)
        }
        EdgeReturn.hold = (NSEvent.mouseLocation, Date().addingTimeInterval(1.5))
        return origin
    }

    /// Brought back by a pinch, the drop-down stays until the pointer moves (spec N-29).
    func holdsRestoredHover() -> Bool {
        guard let hold = EdgeReturn.hold else { return false }
        let point = NSEvent.mouseLocation
        if Date() < hold.until || hypot(point.x - hold.point.x, point.y - hold.point.y) < 4 { return true }
        EdgeReturn.hold = nil
        return false
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
        case .teams: .notifications
        case .recording: nil
        }
    }
}
