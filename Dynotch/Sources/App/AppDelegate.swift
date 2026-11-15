import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private lazy var services = AppServices(
        settings: settings,
        calendar: CalendarService(settings: settings),
        notifications: NotificationService(settings: settings),
        calculator: CalculatorStore()
    )
    private lazy var settingsWindow = SettingsWindowController(
        settings: settings, calendar: services.calendar, notifications: services.notifications
    )
    private var notchManager: NotchManager?
    private var calculatorMenuBar: CalculatorMenuBarController?

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

        let menuBar = CalculatorMenuBarController(settings: settings, store: services.calculator)
        menuBar.start()
        calculatorMenuBar = menuBar
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launching the app again (e.g. from Finder) opens Settings, since there is no Dock icon.
        settingsWindow.show()
        return false
    }
}
