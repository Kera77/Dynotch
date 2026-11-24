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
            // The pointer itself: drawn as a window whenever macOS draws it in software (e.g.
            // while an iPad is a display), always right under the pointer (spec F-12).
            if window.pid == ownPID || window.layer >= cursorLayer { continue }
            return window.layer == 0 ? window : nil
        }
        return nil
    }

    /// `kCGCursorWindowLevel`.
    static let cursorLayer = Int(CGWindowLevelForKey(.cursorWindow))

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
    /// A Dynotch window someone may be typing in. The notch panel keeps reporting itself as
    /// key after it closed (it never activates the app, so nothing takes that from it); it only
    /// counts while it asks for the keyboard (spec F-4, F-11).
    @MainActor
    static func takesKeyboard(_ window: NSWindow) -> Bool {
        guard window.isKeyWindow, window.isVisible else { return false }
        return (window as? NotchPanel)?.allowsKey ?? true
    }

    /// A Dynotch menu (Options, list pickers, the tablet menu) is on screen: letting go of the
    /// keyboard would close it (spec F-18).
    static func hasOpenMenu(in windows: [ScreenWindow], ownPID: pid_t) -> Bool {
        windows.contains { $0.pid == ownPID && $0.layer == popUpMenuLayer }
    }

    /// `kCGPopUpMenuWindowLevel`.
    static let popUpMenuLayer = Int(CGWindowLevelForKey(.popUpMenuWindow))

    /// Windows smaller than this inside the active app are taken for pop-ups (spec F-13).
    static let minimumSwitchSize = CGSize(width: 120, height: 80)

    static let standardSubrole = "AXStandardWindow"
    /// Floating windows at least this large are real windows too (spec F-14b).
    static let minimumFloatingSize = CGSize(width: 300, height: 200)

    /// A window focus may move to inside the active app: a standard window, or a large floating
    /// one (Ardia's mini window is an AXSystemFloatingWindow on the normal layer) (spec F-14b).
    static func isNormalWindow(subrole: String, size: CGSize) -> Bool {
        if subrole == standardSubrole { return true }
        guard ["AXFloatingWindow", "AXSystemFloatingWindow"].contains(subrole) else { return false }
        return size.width >= minimumFloatingSize.width && size.height >= minimumFloatingSize.height
    }

    /// Focus follows windows, not apps (spec F-13): another app's window always; another window
    /// of the active app only when that app's focused window is known and is not a dialog or
    /// sheet (which want to keep the focus), and the target is a standard window, not a pop-up
    /// or drop-down (spec F-14).
    static func shouldSwitch(
        target: ScreenWindow, frontPID: pid_t?, focusedWindow: CGWindowID?, focusedIsDialog: Bool, targetIsStandard: Bool
    ) -> Bool {
        guard target.pid == frontPID else { return true }
        guard let focusedWindow, focusedWindow != target.id, !focusedIsDialog, targetIsStandard else { return false }
        return target.bounds.width >= minimumSwitchSize.width && target.bounds.height >= minimumSwitchSize.height
    }

    /// The active app's focused window keeps the focus unless it is a normal window: a standard
    /// one or a large floating one, so focus can leave Ardia's mini window again (spec F-14c).
    static func focusedKeepsFocus(subrole: String, size: CGSize) -> Bool {
        isDialog(subrole: subrole) || !isNormalWindow(subrole: subrole, size: size)
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
