import AppKit
import ApplicationServices

/// Where the menu bar's own items are, in screen coordinates with the origin at the top left
/// of the main display (as Accessibility and the window list give them) (spec B-8).
struct MenuBarSnapshot: Equatable, Sendable {
    /// The active app's menu titles ("File", "Edit", … "Help").
    var menuItems: [CGRect] = []
    /// Status items of other apps.
    var statusItems: [CGRect] = []
}

/// How much room the menu bar leaves left of the notch (spec B-8).
enum MenuBarSpace {
    /// Kept free between the menu bar's last item and the badges.
    static let gap: CGFloat = 10
    /// Layer of status item windows (kCGStatusWindowLevel).
    static let statusLayer = 25

    /// Reads the active app's menu titles and the status items. Not on the main thread.
    static func snapshot(frontPID: pid_t, ownPID: pid_t) -> MenuBarSnapshot {
        var snapshot = MenuBarSnapshot()
        let app = AXUIElementCreateApplication(frontPID)
        AXUIElementSetMessagingTimeout(app, 0.2)
        var menuBar: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBar) == .success,
           let menuBar, CFGetTypeID(menuBar) == AXUIElementGetTypeID() {
            // swiftlint:disable:next force_cast
            snapshot.menuItems = children(of: menuBar as! AXUIElement).compactMap(frame(of:))
        }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        snapshot.statusItems = windows.compactMap { window in
            guard window[kCGWindowLayer as String] as? Int == statusLayer,
                  window[kCGWindowOwnerPID as String] as? pid_t != ownPID,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect.width > 0
            else { return nil }
            return rect
        }
        return snapshot
    }

    /// A screen's frame in top-left coordinates. `primaryMaxY`: the main display's top.
    static func topLeftFrame(of frame: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryMaxY - frame.maxY, width: frame.width, height: frame.height)
    }

    /// The x where the menu bar's items left of the notch end on one screen, or nil if nothing
    /// is there. Menu titles stand at the same place on every display, so they are measured from
    /// the left edge of the display they were read on.
    /// - Parameters:
    ///   - screen: the screen's frame (AppKit coordinates); `screens`: every screen's frame.
    static func occupiedEdge(
        on screen: CGRect, screens: [CGRect], primaryMaxY: CGFloat, notchMinX: CGFloat, snapshot: MenuBarSnapshot
    ) -> CGFloat? {
        let frames = screens.map { topLeftFrame(of: $0, primaryMaxY: primaryMaxY) }
        let menuEnds = snapshot.menuItems.compactMap { item -> CGFloat? in
            guard let home = frames.first(where: { $0.contains(CGPoint(x: item.midX, y: item.midY)) }) else { return nil }
            return screen.minX + (item.maxX - home.minX)
        }
        let own = topLeftFrame(of: screen, primaryMaxY: primaryMaxY)
        let statusEnds = snapshot.statusItems
            .filter { own.contains(CGPoint(x: $0.midX, y: $0.midY)) }
            .map(\.maxX)
        return (menuEnds + statusEnds).filter { $0 <= notchMinX + 1 }.max()
    }

    /// Room for everything left of the notch; nil: no limit.
    static func room(notchMinX: CGFloat, occupiedEdge: CGFloat?) -> CGFloat? {
        occupiedEdge.map { max(notchMinX - $0 - gap, 0) }
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
        return (value as? [AXUIElement]) ?? []
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size, CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        // swiftlint:disable force_cast
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &extent), extent.width > 0
        else { return nil }
        // swiftlint:enable force_cast
        return CGRect(origin: point, size: extent)
    }
}

/// How many badges fit, and how many wait behind the "+" (spec B-8).
struct BadgeFit: Equatable {
    let shown: [BadgeItem]
    let hidden: Int

    /// All badges if they fit in `room` (or when unfolded); otherwise the first ones that fit
    /// together with the "+".
    static func make(badges: [BadgeItem], items: [IndicatorItem], room: CGFloat?, unfolded: Bool) -> BadgeFit {
        guard let room, !unfolded,
              IndicatorLayout(items: items, badges: badges).leftWidth > room
        else { return BadgeFit(shown: badges, hidden: 0) }
        for count in stride(from: badges.count - 1, through: 0, by: -1) {
            let shown = Array(badges.prefix(count))
            if IndicatorLayout(items: items, badges: shown, overflow: true).leftWidth <= room {
                return BadgeFit(shown: shown, hidden: badges.count - count)
            }
        }
        return BadgeFit(shown: [], hidden: badges.count)
    }
}
