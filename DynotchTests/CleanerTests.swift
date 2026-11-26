import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

struct CleanerTests {
    @Test func itemNamesBecomeBundleIdentifiers() {
        #expect(CleanerScan.bundleID(fromItemName: "com.vendor.app.plist") == "com.vendor.app")
        #expect(CleanerScan.bundleID(fromItemName: "com.vendor.app.savedState") == "com.vendor.app")
        #expect(CleanerScan.bundleID(fromItemName: "Google") == nil)
        #expect(CleanerScan.bundleID(fromItemName: "com.vendor") == nil)
        #expect(CleanerScan.bundleID(fromItemName: "My App.v2.data") == nil)
        #expect(CleanerScan.bundleID(fromItemName: "2.0.1") == nil)
    }

    @Test func appleAndInstalledVendorsAreNeverLeftovers() {
        let installed: Set<String> = ["com.google.drivefs"]
        #expect(CleanerScan.isInUse("com.apple.Safari", installed: [], running: []))
        #expect(CleanerScan.isInUse("com.google.Chrome", installed: installed, running: []))
        #expect(CleanerScan.isInUse("com.gone.helper", installed: [], running: ["com.gone.helper.agent"]))
        #expect(!CleanerScan.isInUse("com.surely-not-installed-vendor.app", installed: installed, running: []))
    }

    @Test func removesOnlyInTheHomeLibraryAndAppFolders() {
        let library = CleanerScan.library
        #expect(CleanerScan.mayRemove(library.appending(path: "Caches/com.gone.app")))
        #expect(CleanerScan.mayRemove(URL(filePath: "/Applications/Gone.app")))
        #expect(!CleanerScan.mayRemove(library))
        #expect(!CleanerScan.mayRemove(library.appending(path: "Preferences/com.apple.finder.plist")))
        #expect(!CleanerScan.mayRemove(URL(filePath: "/System/Applications/Mail.app")))
        #expect(!CleanerScan.mayRemove(CleanerScan.home.appending(path: "Documents/file.txt")))
    }

    @Test func peeksAreAsNarrowAsTheNotchWhenTheyFit() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        let notch = geometry.notchSize.width
        #expect(geometry.fittedPeekWidth(content: 100, upTo: 320) == notch)
        #expect(geometry.fittedPeekWidth(content: notch + 30, upTo: 320) == notch + 30)
        #expect(geometry.fittedPeekWidth(content: 900, upTo: 320) == 320)
        let event = DeviceEvent(category: .usb, name: "Key", symbol: "cable.connector", isConnected: true)
        #expect(geometry.devicePeekSize(for: event).width == notch)
    }
}
