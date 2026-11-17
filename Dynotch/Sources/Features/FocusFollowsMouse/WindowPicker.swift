import AppKit
import CoreGraphics
import Foundation

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

/// When focus must not follow the pointer (spec F-8).
enum FocusRules {
    /// Focus only moves to another app, never between the windows of the active one.
    /// A Dynotch window someone may be typing in. The notch panel keeps reporting itself as
    /// key after it closed (it never activates the app, so nothing takes that from it); it only
    /// counts while it asks for the keyboard (spec F-4, F-11).
    @MainActor
    static func takesKeyboard(_ window: NSWindow) -> Bool {
        guard window.isKeyWindow, window.isVisible else { return false }
        return (window as? NotchPanel)?.allowsKey ?? true
    }

    static func shouldSwitch(targetPID: pid_t, frontPID: pid_t?) -> Bool {
        targetPID != frontPID
    }

    static func isDialog(subrole: String) -> Bool {
        ["AXDialog", "AXSystemDialog", "AXSheet"].contains(subrole)
    }

    /// An app may refuse a focus change (e.g. while it shows an alert) and take the focus back;
    /// asking again and again makes its windows flicker.
    struct Attempts: Equatable {
        static let limit = 2
        private(set) var window: CGWindowID?
        private(set) var count = 0

        /// - Returns: false once the same window was tried `limit` times in a row.
        mutating func shouldTry(_ target: CGWindowID) -> Bool {
            if window != target {
                window = target
                count = 0
            }
            guard count < Self.limit else { return false }
            count += 1
            return true
        }

        mutating func reset() {
            window = nil
            count = 0
        }
    }
}
