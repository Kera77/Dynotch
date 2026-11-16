import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private lazy var notifications = NotificationService(settings: settings)
    private lazy var services = AppServices(
        settings: settings,
        calendar: CalendarService(settings: settings),
        notifications: notifications,
        calculator: CalculatorStore(),
        notes: NotesStore(),
        reminders: RemindersStore(),
        claudeUsage: ClaudeUsageService(settings: settings) { [notifications] title, body in
            notifications.present(title: title, body: body, appIdentifier: "com.anthropic.claudefordesktop")
        },
        hud: HUDService(settings: settings),
        badges: BadgeService(),
        calls: CallService(settings: settings),
        keyboardLock: KeyboardLock(),
        shortcuts: ShortcutStore(),
        notices: NoticeService()
    )
    private lazy var settingsWindow = SettingsWindowController(
        services: services
    )
    private var notchManager: NotchManager?
    private var hotkeys: HotkeyCenter?
    private var menuBarPanels: [MenuBarPopoverController] = []
    private lazy var focusFollowsMouse = FocusFollowsMouse(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app host; don't put a panel on screen there.
        guard !AppInfo.isRunningTests else { return }

        services.calendar.start()
        services.notifications.start()
        // Loads the open count for the menu bar icon if access was granted before; never prompts.
        services.reminders.start()
        focusFollowsMouse.start()
        services.claudeUsage.start()
        services.hud.start()
        services.badges.start()
        services.calls.start()
        NSApp.mainMenu = EditMenu.make()

        let manager = NotchManager(services: services) { [weak self] in
            self?.settingsWindow.show()
        }
        manager.start()
        notchManager = manager

        let shortcuts = services.shortcuts
        let center = HotkeyCenter(store: shortcuts) { [weak manager] feature in
            manager?.open(feature, pinned: shortcuts.pinsOnOpen)
        }
        center.start()
        hotkeys = center

        menuBarPanels = makeMenuBarPanels()
        menuBarPanels.forEach { $0.start() }
    }

    private func makeMenuBarPanels() -> [MenuBarPopoverController] {
        let calculator = services.calculator
        let notes = services.notes
        let reminders = services.reminders
        let usage = services.claudeUsage
        return [
            MenuBarPopoverController(feature: .calculator, panelSize: NSSize(width: 440, height: 340), settings: settings) {
                AnyView(CalculatorMenuBarView(store: calculator, state: $0))
            },
            MenuBarPopoverController(
                feature: .notes, panelSize: NSSize(width: 680, height: 440), settings: settings,
                onOpen: { notes.activate() },
                makeContent: { AnyView(NotesMenuBarView(store: notes, state: $0)) }
            ),
            MenuBarPopoverController(
                feature: .reminders,
                panelSize: NSSize(width: 400, height: 520),
                settings: settings,
                badge: Badge(changes: reminders.objectWillChange) { reminders.access == .granted ? reminders.openCount : nil },
                onOpen: { reminders.activate() },
                makeContent: { AnyView(RemindersMenuBarView(store: reminders, state: $0)) }
            ),
            MenuBarPopoverController(
                feature: .claudeUsage,
                panelSize: NSSize(width: 340, height: 300),
                settings: settings,
                icon: StatusIcon(
                    changes: usage.objectWillChange,
                    image: { nil },
                    toolTip: { usage.limits.isEmpty ? nil : "Claude · " + usage.summary }
                ),
                onOpen: { usage.refreshIfStale() },
                makeContent: { AnyView(ClaudeUsageMenuBarView(service: usage, state: $0)) }
            )
        ]
    }

    /// dynotch:// links, e.g. from Claude Code's Stop hook (spec CN-2).
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !AppInfo.isRunningTests else { return }
        urls.forEach(services.notices.handle)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launching the app again (e.g. from Finder) opens Settings, since there is no Dock icon.
        settingsWindow.show()
        return false
    }
}
