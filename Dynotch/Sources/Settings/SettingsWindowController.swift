import AppKit
import SwiftUI

/// Hosts SettingsView in a regular window (spec C-3). The app has no Dock icon or main menu,
/// so SwiftUI's `Settings` scene can't be opened reliably; a plain NSWindow can.
@MainActor
final class SettingsWindowController {
    private let settings: AppSettings
    private let calendar: CalendarService
    private let notifications: NotificationService
    private let badges: BadgeService
    private var window: NSWindow?

    init(settings: AppSettings, calendar: CalendarService, notifications: NotificationService, badges: BadgeService) {
        self.settings = settings
        self.calendar = calendar
        self.notifications = notifications
        self.badges = badges
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let rootView = SettingsView(settings: settings, calendar: calendar, notifications: notifications, badges: badges)
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = "Dynotch Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
