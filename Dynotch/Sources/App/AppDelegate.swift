import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private lazy var calendar = CalendarService(settings: settings)
    private lazy var settingsWindow = SettingsWindowController(settings: settings, calendar: calendar)
    private var notchManager: NotchManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app host; don't put a panel on screen there.
        guard !AppInfo.isRunningTests else { return }

        calendar.start()
        let manager = NotchManager(settings: settings, calendar: calendar) { [weak self] in
            self?.settingsWindow.show()
        }
        manager.start()
        notchManager = manager
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launching the app again (e.g. from Finder) opens Settings, since there is no Dock icon.
        settingsWindow.show()
        return false
    }
}
