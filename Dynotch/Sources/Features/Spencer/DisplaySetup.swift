import AppKit
import CoreGraphics

/// One connected display, as the window server tells it.
struct DisplayInfo: Equatable, Sendable {
    let vendor: UInt32
    let model: UInt32
    let serial: UInt32
    let name: String
    let isBuiltin: Bool
}

/// The connected displays, recognised again whatever their resolution, arrangement or main
/// display: the built-in one, an iPad through Sidecar and each monitor by its make and serial
/// (spec SL-3).
struct DisplaySetup: Equatable, Sendable {
    /// Stable id of the set of displays, for the remembered layouts.
    let key: String
    /// For the menu and the notice, e.g. "Built-in + DELL U2720Q + iPad".
    let title: String
    let count: Int

    static func make(_ displays: [DisplayInfo]) -> DisplaySetup {
        let ordered = displays.sorted { (rank(of: $0), $0.name) < (rank(of: $1), $1.name) }
        return DisplaySetup(
            key: displays.map(part(of:)).sorted().joined(separator: "+"),
            title: ordered.map { $0.isBuiltin ? "Built-in" : $0.name }.joined(separator: " + "),
            count: displays.count
        )
    }

    /// One display's part of the key: an iPad by its name, a monitor without a serial by its name too.
    static func part(of display: DisplayInfo) -> String {
        if display.isBuiltin { return "builtin" }
        if isSidecar(display.name) { return "sidecar:\(display.name)" }
        let id = "\(display.vendor)-\(display.model)"
        return display.serial == 0 ? "\(id)-\(display.name)" : "\(id)-\(display.serial)"
    }

    static func isSidecar(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("ipad") || name.localizedCaseInsensitiveContains("sidecar")
    }

    /// The built-in display first, iPads last.
    private static func rank(of display: DisplayInfo) -> Int {
        if display.isBuiltin { return 0 }
        return isSidecar(display.name) ? 2 : 1
    }

    /// The displays connected now.
    @MainActor
    static func current() -> DisplaySetup {
        make(NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let id = CGDirectDisplayID(number.uint32Value)
            return DisplayInfo(
                vendor: CGDisplayVendorNumber(id), model: CGDisplayModelNumber(id), serial: CGDisplaySerialNumber(id),
                name: screen.localizedName, isBuiltin: CGDisplayIsBuiltin(id) != 0
            )
        })
    }
}
