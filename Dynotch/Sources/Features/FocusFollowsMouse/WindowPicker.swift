import Foundation
import CoreGraphics

/// An on-screen window, from `CGWindowListCopyWindowInfo`.
struct ScreenWindow: Equatable, Sendable {
    let id: CGWindowID
    let pid: pid_t
    /// Global coordinates, origin at the top left of the main display.
    let bounds: CGRect
    /// 0 = normal windows; menus, the Dock, the menu bar etc. are above.
    let layer: Int
    let alpha: Double
}

/// Pure choice of the window under the pointer (spec F-2).
enum WindowPicker {
    /// The topmost window under the point if it is a normal window of another app. A menu, the
    /// Dock, the menu bar or a floating window on top means "do nothing" (nil). Dynotch's own
    /// windows are looked through, since they are mostly transparent.
    static func window(at point: CGPoint, in windows: [ScreenWindow], ownPID: pid_t) -> ScreenWindow? {
        for window in windows where window.bounds.contains(point) && window.alpha > 0.01 {
            if window.pid == ownPID { continue }
            return window.layer == 0 ? window : nil
        }
        return nil
    }

    /// Parses the dictionaries `CGWindowListCopyWindowInfo` returns (front to back).
    static func screenWindows(from info: [[String: Any]]) -> [ScreenWindow] {
        info.compactMap { entry in
            guard let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsDictionary = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
            else { return nil }
            return ScreenWindow(
                id: id,
                pid: pid,
                bounds: bounds,
                layer: entry[kCGWindowLayer as String] as? Int ?? 0,
                alpha: entry[kCGWindowAlpha as String] as? Double ?? 1
            )
        }
    }
}
