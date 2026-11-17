import AppKit
import SwiftUI

/// Hosts SettingsView in a regular window (spec C-3). The app has no Dock icon or main menu,
/// so SwiftUI's `Settings` scene can't be opened reliably; a plain NSWindow can.
@MainActor
final class SettingsWindowController {
    private let services: AppServices
    private var window: NSWindow?

    init(services: AppServices) {
        self.services = services
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let rootView = SettingsView(
            settings: services.settings, calendar: services.calendar, notifications: services.notifications,
            badges: services.badges, shortcuts: services.shortcuts, updates: services.updates
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = "Dynotch Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
