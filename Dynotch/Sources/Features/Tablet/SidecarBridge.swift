import AppKit
import CoreGraphics

/// The private SidecarCore framework: the iPads that can be a display of this Mac, connecting
/// and disconnecting them (spec TB-2). Looked up at run time; missing pieces mean "no tablets".
enum SidecarBridge {
    private static let isLoaded = dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore", RTLD_NOW) != nil

    private static var manager: NSObject? {
        guard isLoaded, let type = NSClassFromString("SidecarDisplayManager") as? NSObject.Type else { return nil }
        let selector = NSSelectorFromString("sharedManager")
        guard type.responds(to: selector) else { return nil }
        return type.perform(selector)?.takeUnretainedValue() as? NSObject
    }

    static var isSupported: Bool { manager != nil }

    /// - Parameter key: "devices" (all that can be used) or "connectedDevices".
    static func devices(_ key: String) -> [NSObject] {
        guard let manager, manager.responds(to: NSSelectorFromString(key)) else { return [] }
        return manager.value(forKey: key) as? [NSObject] ?? []
    }

    static func identifier(of device: NSObject) -> String? {
        guard device.responds(to: NSSelectorFromString("identifier")) else { return nil }
        return device.value(forKey: "identifier").map { "\($0)" }
    }

    static func name(of device: NSObject) -> String {
        guard device.responds(to: NSSelectorFromString("name")) else { return "iPad" }
        return device.value(forKey: "name") as? String ?? "iPad"
    }

    /// - Parameters:
    ///   - selectorName: "connectToDevice:completion:" or "disconnectFromDevice:completion:".
    ///   - completion: called on any queue once the system is done, with the failure's text.
    /// - Returns: false when the framework does not offer it.
    static func perform(_ selectorName: String, device: NSObject, completion: @escaping @Sendable (String?) -> Void) -> Bool {
        guard let manager else { return false }
        let selector = NSSelectorFromString(selectorName)
        guard manager.responds(to: selector) else { return false }
        let block: @convention(block) (NSError?) -> Void = { error in completion(error?.localizedDescription) }
        manager.perform(selector, with: device, with: unsafeBitCast(block, to: AnyObject.self))
        return true
    }
}

/// The display an iPad provides, found by the vendor and model the system gives it (they stay
/// while it mirrors, when it is missing from `NSScreen.screens`), and its mirroring (spec TB-3).
enum SidecarDisplay {
    static let vendorNumber: UInt32 = 1_633_775_724
    static let modelNumber: UInt32 = 1_766_875_492
    private static let noDisplay = CGDirectDisplayID(0)

    static func displayID() -> CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &count) == .success else { return nil }
        let online = ids.prefix(Int(count))
        if let match = online.first(where: { CGDisplayVendorNumber($0) == vendorNumber && CGDisplayModelNumber($0) == modelNumber }) {
            return match
        }
        return NSScreen.screens.first { $0.localizedName.contains("Sidecar") }
            .flatMap { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID }
    }

    /// The screen is an iPad's: Dynotch puts no notch there (spec TB-10).
    static func isTablet(_ screen: NSScreen) -> Bool {
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return screen.localizedName.contains("Sidecar")
        }
        return (CGDisplayVendorNumber(id) == vendorNumber && CGDisplayModelNumber(id) == modelNumber)
            || screen.localizedName.contains("Sidecar")
    }

    static func isMirrored(_ display: CGDirectDisplayID) -> Bool {
        CGDisplayMirrorsDisplay(display) != noDisplay
    }

    /// Mirrors the main display on the iPad, or extends the desktop onto it again.
    static func setMirrored(_ mirrored: Bool, display: CGDirectDisplayID) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }
        let source = mirrored ? CGMainDisplayID() : noDisplay
        guard CGConfigureDisplayMirrorOfDisplay(config, display, source) == .success else {
            CGCancelDisplayConfiguration(config)
            return false
        }
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }
}
