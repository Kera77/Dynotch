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
        var subrole: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole) == .success,
              let name = subrole as? String
        else { return false }
        return FocusRules.isDialog(subrole: name)
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

        // A button went down meanwhile: the user's click activates the app by itself.
        guard NSEvent.pressedMouseButtons == 0, setFrontProcess(&psn, windowID, userGenerated) == 0 else { return false }

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
