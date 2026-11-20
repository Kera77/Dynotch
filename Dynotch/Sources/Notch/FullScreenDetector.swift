import AppKit

/// Finds a full-screen app on a display: one of its windows covers the whole screen, the menu
/// bar's strip included (spec N-12). Only window frames are read, never their content.
enum FullScreenDetector {
    /// - Parameters:
    ///   - screenFrame: the display, in AppKit coordinates (origin bottom-left).
    ///   - primaryHeight: height of the primary display, to convert to window coordinates.
    static func hasFullScreenWindow(in windows: [ListedWindow], screenFrame: CGRect, primaryHeight: CGFloat) -> Bool {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let target = windowRect(of: screenFrame, primaryHeight: primaryHeight)
        return windows.contains { $0.layer == 0 && $0.pid != ownPID && covers($0.frame, target) }
    }

    /// AppKit screen coordinates → window-server coordinates (origin top-left of the primary display).
    static func windowRect(of frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    /// A window covers the screen when its frame matches it (a zoomed window leaves the menu bar).
    static func covers(_ window: CGRect, _ screen: CGRect) -> Bool {
        abs(window.minX - screen.minX) < 1 && abs(window.minY - screen.minY) < 1
            && abs(window.width - screen.width) < 1 && abs(window.height - screen.height) < 1
    }
}

extension NotchController {
    static let fullScreenCheckInterval: TimeInterval = 1

    func startFullScreenChecks() {
        fullScreenWatch = WindowListMonitor.shared.subscribe(every: Self.fullScreenCheckInterval) { [weak self] windows in
            self?.checkFullScreen(windows)
        }
    }

    /// Right after a Space change: a fresh look instead of waiting for the next tick.
    func checkFullScreenNow() {
        Task { [weak self] in
            let windows = await Task.detached { WindowListMonitor.onScreenWindows() }.value
            self?.checkFullScreen(windows)
        }
    }

    func stopFullScreenChecks() {
        if let fullScreenWatch { WindowListMonitor.shared.unsubscribe(fullScreenWatch) }
        fullScreenWatch = nil
    }

    /// Hides the closed notch while a full-screen app is in front on this display (spec N-12).
    func checkFullScreen(_ windows: [ListedWindow]) {
        guard settings.hideInFullScreen else {
            model.setHiddenForFullScreen(false)
            return
        }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? model.geometry.screenFrame.height
        let hidden = FullScreenDetector.hasFullScreenWindow(
            in: windows, screenFrame: model.geometry.screenFrame, primaryHeight: primaryHeight
        )
        guard hidden != model.isHiddenForFullScreen else { return }
        DiagnosticsLog.append("fullscreen", "\(model.screenName): hidden=\(hidden)")
        model.setHiddenForFullScreen(hidden)
        if hidden {
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
        }
    }

    /// Area that opens the panel: the notch, or the whole peek while a notification shows.
    var hoverZone: CGRect {
        let geometry = model.geometry
        // A notification beside the notch in Wings mode opens only with a swipe down (spec PV-13).
        guard notifications.peek != nil, !settings.noticesBeside else { return reachingDown(geometry.hoverZone) }
        // The notification hangs under the row, as wide as it and moved with it (spec E-24b).
        let layout = collapsedRow().layout
        let peek = notifications.peekSize(in: geometry)
        let row = layout.isEmpty ? 0 : layout.size(notch: geometry.notchSize, labelHeight: nil).width
        let zone = geometry.keepOpenZone(for: CGSize(width: max(peek.width, row), height: peek.height))
        return reachingDown(zone.offsetBy(dx: layout.horizontalOffset, dy: 0))
    }

    /// Whether the pointer opens the closed notch here. Over a notification the row beside the
    /// notch (badges, indicators) stays usable; the notch and the notification open (spec E-24).
    func opens(at point: CGPoint) -> Bool {
        guard openingZone.contains(point) else {
            dropDownHoverSince = nil
            return false
        }
        // A small notice beside the notch: hovering leaves it, a swipe up puts it away first (spec PV-47).
        if settings.noticesBeside, showsWingsPeek { return false }
        // A small notice under the notch: the Wings wait for the pointer to rest a moment (spec PV-71).
        if holdsWingsForDropDown() { return false }
        guard notifications.peek != nil else { return true }
        // A notification in the wings opens only with a swipe down (spec PV-13).
        if settings.noticesBeside { return false }
        let notch = model.geometry.notchRect
        let inRowBeside = point.y >= notch.minY && !notch.insetBy(dx: -4, dy: 0).contains(point)
        return !inRowBeside
    }

    /// The area that opens the closed notch: over a full-screen app only the top edge.
    var openingZone: CGRect {
        if model.isHiddenForFullScreen { return model.geometry.topEdgeZone }
        // With the module strip, the notch's bottom edge shows the strip instead (spec MS-2).
        // In preview mode the whole notch opens the preview, the strip comes with it (spec PV-6).
        guard settings.moduleStrip, !settings.hoverPreview, notifications.peek == nil else { return hoverZone }
        let zone = hoverZone
        let bandTop = stripBand.maxY
        return CGRect(x: zone.minX, y: bandTop, width: zone.width, height: max(zone.maxY - bandTop, 0))
    }
}
