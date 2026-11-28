import AppKit
import SwiftUI

/// The rename bridge (spec RN-9, RN-10): an old Dynotch updater installs it as Dynotch.app; it
/// shows a small window, puts the Wingmate of the same release in place and quits.
@MainActor
final class BridgeDelegate: NSObject, NSApplicationDelegate {
    private let model = BridgeModel()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 160), styleMask: [.titled],
            backing: .buffered, defer: false
        )
        window.title = "Wingmate"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentView = NSHostingView(rootView: BridgeView(model: model))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        model.start()
    }
}
