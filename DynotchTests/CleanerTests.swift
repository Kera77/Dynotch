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

/// The disk bar, the apps' last use, large files and the sessions' step (spec TT-18, TT-20, TT-21, CS-11).
@MainActor
struct CleanerExtrasTests {
    @Test func diskBarAddsUpToTheDisk() {
        let found = CleanerDiskBar.Found(apps: 30, caches: 10, leftovers: 5, rest: DiskBreakdown(system: 20, appData: 0, files: 15))
        let parts = CleanerDiskBar.parts(total: 200, free: 100, found: found)
        // Largest first; an empty part is left out (spec TT-23, TT-24).
        #expect(parts.map(\.title) == ["Free", "Apps", "System", "Other", "Files", "Caches", "Leftovers"])
        #expect(parts.reduce(0) { $0 + $1.size } == 200)
        let over = CleanerDiskBar.parts(total: 200, free: 100, found: .init(apps: 80, caches: 40, leftovers: 0))
        #expect(over.reduce(0) { $0 + $1.size } == 200)
        #expect(CleanerDiskBar.parts(total: 200, free: 100, found: nil).map(\.size) == [100, 100])
    }

    @Test func lastUsedWords() {
        let now = Date()
        #expect(CleanerAppRow.lastUsed(nil, now: now) == "Never opened")
        #expect(CleanerAppRow.lastUsed(now.addingTimeInterval(-3600), now: now) == "Opened today")
        #expect(CleanerAppRow.lastUsed(now.addingTimeInterval(-125 * 86_400), now: now) == "Not opened for 4 months")
    }

    @Test func largeFilesOnlyFromTheirTab() {
        let file = CleanerScan.home.appending(path: "Downloads/big.dmg")
        #expect(!CleanerScan.mayRemove(file))
        #expect(CleanerScan.mayRemove(file, largeFile: true))
        #expect(!CleanerScan.mayRemove(URL(filePath: "/System/big.dmg"), largeFile: true))
    }

    @Test func sessionStepAndAnswerFromTheTranscript() {
        let lines = [
            ###"{"type":"assistant","message":{"content":[{"type":"text","text":"## Done: added the rows\nMore"}]}}"###,
            #"{"type":"user","message":{"content":"next"}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/a/b/NotchView.swift"}}]}}"#
        ]
        let reading = ClaudeSessionActivity.parse(lines.joined(separator: "\n"))
        #expect(reading.activity == "Editing NotchView.swift")
        #expect(reading.answer == "Done: added the rows")
        #expect(ClaudeSessionActivity.describe(tool: "Bash", input: ["description": "Build the app"]) == "Running: Build the app")
    }
}
