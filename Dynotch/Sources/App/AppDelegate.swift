import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private lazy var services = AppServices(
        settings: settings,
        calendar: CalendarService(settings: settings),
        notifications: NotificationService(settings: settings),
        calculator: CalculatorStore(),
        notes: NotesStore()
    )
    private lazy var settingsWindow = SettingsWindowController(
        settings: settings, calendar: services.calendar, notifications: services.notifications
    )
    private var notchManager: NotchManager?
    private var menuBarPanels: [MenuBarPopoverController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app host; don't put a panel on screen there.
        guard !AppInfo.isRunningTests else { return }

        services.calendar.start()
        services.notifications.start()

        let manager = NotchManager(services: services) { [weak self] in
            self?.settingsWindow.show()
        }
        manager.start()
        notchManager = manager

        let calculator = services.calculator
        let notes = services.notes
        menuBarPanels = [
            MenuBarPopoverController(feature: .calculator, panelSize: NSSize(width: 440, height: 340), settings: settings) {
                AnyView(CalculatorMenuBarView(store: calculator, state: $0))
            },
            MenuBarPopoverController(feature: .notes, panelSize: NSSize(width: 680, height: 440), settings: settings) {
                AnyView(NotesMenuBarView(store: notes, state: $0))
            }
        ]
        menuBarPanels.forEach { $0.start() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launching the app again (e.g. from Finder) opens Settings, since there is no Dock icon.
        settingsWindow.show()
        return false
    }
}
