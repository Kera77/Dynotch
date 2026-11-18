import AppKit
import ApplicationServices

/// Focuses a window without raising it, through private window server calls (the technique
/// AutoRaise and yabai use). Every symbol is looked up at run time; if one is missing on a
/// macOS version, focusing is simply unavailable.
enum SkyLightFocus {
    private typealias SetFrontProcess = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UInt32, UInt32) -> Int32
    private typealias PostEventRecord = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> Int32
    private typealias GetProcessForPID = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> Int32
    private typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> AXError

    /// `kCPSUserGenerated`: the switch counts as a user action.
    private static let userGenerated: UInt32 = 0x200

    nonisolated(unsafe) private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    nonisolated(unsafe) private static let setFrontProcess: SetFrontProcess? = symbol("_SLPSSetFrontProcessWithOptions", in: skyLight)
    nonisolated(unsafe) private static let postEventRecord: PostEventRecord? = symbol("SLPSPostEventRecordTo", in: skyLight)
    nonisolated(unsafe) private static let getProcessForPID: GetProcessForPID? = symbol("GetProcessForPID", in: nil)
    nonisolated(unsafe) private static let getWindow: GetWindow? = symbol("_AXUIElementGetWindow", in: nil)

    static var isAvailable: Bool {
        setFrontProcess != nil && postEventRecord != nil && getProcessForPID != nil
    }

    private static func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer?) -> T? {
        let address = dlsym(handle ?? UnsafeMutableRawPointer(bitPattern: -2), name) // -2 = RTLD_DEFAULT
        return address.map { unsafeBitCast($0, to: T.self) }
    }

    /// The app's Accessibility window with this window id, e.g. to raise it (spec AS-13).
    static func axWindow(pid: pid_t, windowID: CGWindowID) -> AXUIElement? {
        guard let getWindow else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.3)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return nil }
        return windows.first { window in
            var id: UInt32 = 0
            return getWindow(window, &id) == .success && id == windowID
        }
    }

    /// The ids of an app's minimized windows (Accessibility), for the switcher (spec AS-3).
    static func minimizedWindowIDs(of pid: pid_t) -> [CGWindowID] {
        guard let getWindow else { return [] }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return [] }
        return windows.compactMap { window in
            var minimized: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized)
            var id: UInt32 = 0
            guard minimized as? Bool == true, getWindow(window, &id) == .success, id != 0 else { return nil }
            return id
        }
    }

    /// The window id of the focused window of an app (needs Accessibility).
    static func focusedWindowID(of pid: pid_t) -> CGWindowID? {
        guard let getWindow else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        var windowID: UInt32 = 0
        // swiftlint:disable:next force_cast
        guard getWindow(value as! AXUIElement, &windowID) == .success, windowID != 0 else { return nil }
        return windowID
    }

    /// True if `windowID` is one of the app's standard windows (AXStandardWindow): not a pop-up,
    /// drop-down, menu or tooltip, which are windows of their own in e.g. JetBrains apps and close
    /// when they lose the focus (spec F-14).
    static func isStandardWindow(pid: pid_t, windowID: CGWindowID) -> Bool {
        guard let getWindow else { return false }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return false }
        for window in windows {
            var id: UInt32 = 0
            guard getWindow(window, &id) == .success, id == windowID else { continue }
            var subrole: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole) == .success else { return false }
            return (subrole as? String) == FocusRules.standardSubrole
        }
        return false
    }

    /// True if the app's focused window is a dialog, alert or sheet: it wants to keep the focus
    /// (spec F-8).
    static func hasFocusedDialog(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return false }
        // swiftlint:disable:next force_cast
        let window = value as! AXUIElement
        var modal: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXModalAttribute as CFString, &modal) == .success, (modal as? Bool) == true {
            return true
        }
        // Anything but a standard window (a dialog, a pop-up or drop-down with the focus, or one
        // without a subrole) keeps the focus inside its app (spec F-14).
        var subrole: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole) == .success,
              let name = subrole as? String
        else { return true }
        return FocusRules.isDialog(subrole: name) || name != FocusRules.standardSubrole
    }

    /// Makes `windowID` of `pid` the key window and its app the active one, leaving the window
    /// order on screen unchanged.
    @discardableResult
    static func focusWithoutRaise(pid: pid_t, windowID: CGWindowID, focusedPID: pid_t?, focusedWindowID: CGWindowID?) -> Bool {
        guard let setFrontProcess, let postEventRecord, var psn = processSerialNumber(for: pid) else { return false }

        // Switching windows inside the active app: tell the old window it lost focus first.
        if focusedPID == pid, let focusedWindowID, var focusedPSN = processSerialNumber(for: pid) {
            var deactivate = eventRecord(windowID: focusedWindowID)
            deactivate[0x08] = 0x0d
            deactivate[0x8a] = 0x02
            _ = postEventRecord(&focusedPSN, &deactivate)
            usleep(10_000)
            var activate = eventRecord(windowID: windowID)
            activate[0x08] = 0x0d
            activate[0x8a] = 0x01
            _ = postEventRecord(&psn, &activate)
        }

        guard setFrontProcess(&psn, windowID, userGenerated) == 0 else { return false }

        // Make the window key without ordering it front.
        for kind: UInt8 in [0x01, 0x02] {
            var record = eventRecord(windowID: windowID)
            record[0x08] = kind
            record[0x3a] = 0x10
            for index in 0x20..<0x30 { record[index] = 0xff }
            _ = postEventRecord(&psn, &record)
        }
        return true
    }

    private static func processSerialNumber(for pid: pid_t) -> ProcessSerialNumber? {
        guard let getProcessForPID else { return nil }
        var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: 0)
        return getProcessForPID(pid, &psn) == 0 ? psn : nil
    }

    /// A 0xf8-byte window server event record carrying the window id at 0x3c.
    private static func eventRecord(windowID: CGWindowID) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        withUnsafeBytes(of: windowID.littleEndian) { raw in
            for (offset, byte) in raw.enumerated() { bytes[0x3c + offset] = byte }
        }
        return bytes
    }
}
