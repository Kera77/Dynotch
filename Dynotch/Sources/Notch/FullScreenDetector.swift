import AppKit

/// Finds a full-screen app on a display: one of its windows covers the whole screen, the menu
/// bar's strip included (spec N-12). Only window frames are read, never their content.
enum FullScreenDetector {
    /// - Parameters:
    ///   - screenFrame: the display, in AppKit coordinates (origin bottom-left).
    ///   - primaryHeight: height of the primary display, to convert to window coordinates.
    static func hasFullScreenWindow(screenFrame: CGRect, primaryHeight: CGFloat) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return false }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let target = windowRect(of: screenFrame, primaryHeight: primaryHeight)
        return list.contains { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? Int32) != ownPID,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat]
            else { return false }
            let rect = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            return covers(rect, target)
        }
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
        let timer = Timer(timeInterval: Self.fullScreenCheckInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkFullScreen() }
        }
        RunLoop.main.add(timer, forMode: .common)
        fullScreenTimer = timer
    }

    func stopFullScreenChecks() {
        fullScreenTimer?.invalidate()
        fullScreenTimer = nil
    }

    /// Hides the closed notch while a full-screen app is in front on this display (spec N-12).
    func checkFullScreen() {
        // The same tick notes copies, for the smart opening (spec SO-2).
        ClipboardWatcher.shared.poll()
        guard settings.hideInFullScreen else {
            model.setHiddenForFullScreen(false)
            return
        }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? model.geometry.screenFrame.height
        let hidden = FullScreenDetector.hasFullScreenWindow(
            screenFrame: model.geometry.screenFrame, primaryHeight: primaryHeight
        )
        guard hidden != model.isHiddenForFullScreen else { return }
        DiagnosticsLog.append("fullscreen", "\(model.screenName): hidden=\(hidden)")
        model.setHiddenForFullScreen(hidden)
        if hidden {
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
        }
    }

    /// The area that opens the closed notch: over a full-screen app only the top edge.
    var openingZone: CGRect {
        if model.isHiddenForFullScreen { return model.geometry.topEdgeZone }
        // With the module strip, the notch's bottom edge shows the strip instead (spec MS-2).
        guard settings.moduleStrip, notifications.peek == nil else { return hoverZone }
        let zone = hoverZone
        let bandTop = stripBand.maxY
        return CGRect(x: zone.minX, y: bandTop, width: zone.width, height: max(zone.maxY - bandTop, 0))
    }
}
