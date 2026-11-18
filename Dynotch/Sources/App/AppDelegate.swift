import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private lazy var notifications = NotificationService(settings: settings)
    private lazy var clipboard = ClipboardStore()
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
        notices: NoticeService(),
        chat: ClaudeChatService(),
        battery: BatteryService(settings: settings),
        updates: UpdateService(),
        tablets: TabletDisplayService(),
        clipboard: clipboard,
        clipboardPicker: ClipboardPicker(store: clipboard),
        tray: TrayStore(),
        beeper: BeeperService(),
        devices: DeviceWatcher(settings: settings)
    )
    private lazy var settingsWindow = SettingsWindowController(
        services: services
    )
    private var notchManager: NotchManager?
    private var textService: TextServiceProvider?
    /// Keeps App Nap away: after a long idle time the first opening of the notch lagged while the
    /// app woke up (spec N-14). Idle system sleep is still allowed.
    private let noNap = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiatedAllowingIdleSystemSleep], reason: "The notch reacts to the pointer at once"
    )
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
        ClaudeHook.upgradeIfNeeded()
        ClaudeQuestionHook.upgradeIfNeeded()
        services.battery.onCharged = { [notifications] device in
            notifications.present(title: "\(device.name) is charged", body: "100%", appIdentifier: AppInfo.bundleIdentifier)
        }
        services.battery.start()
        services.updates.start()
        let notices = services.notices
        services.chat.onAnswerReady = { chat in
            notices.show(StickyNotice(title: "\(chat.service.title) answered", detail: chat.title, date: Date(), opensChat: true))
        }
        NSApp.mainMenu = EditMenu.make()

        let manager = NotchManager(services: services) { [weak self] in
            self?.settingsWindow.show()
        }
        manager.start()
        notchManager = manager
        announceUpdate()
        offerTextService(manager)

        // The clipboard works even when its module is not in the notch (spec CB-1).
        services.clipboard.start()
        services.clipboardPicker.present = { [weak manager] shown in manager?.showClipboardPicker(shown) }
        services.clipboardPicker.start()
        services.beeper.start()
        services.devices.start()

        let shortcuts = services.shortcuts
        let center = HotkeyCenter(
            store: shortcuts,
            onFire: { [weak manager] in manager?.open($0, pinned: shortcuts.pinsWhenOpened($0)) },
            onPin: { [weak manager] in manager?.togglePin() }
        )
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
        let chat = services.chat
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
            ),
            MenuBarPopoverController(
                feature: .claudeChat,
                panelSize: NSSize(width: 640, height: 470),
                settings: settings,
                icon: StatusIcon(changes: chat.objectWillChange, image: { nil }, toolTip: { "AI" }),
                onOpen: { chat.isVisibleInMenuBar = true },
                onClose: { chat.isVisibleInMenuBar = false },
                makeContent: { AnyView(ClaudeChatMenuBarView(service: chat, state: $0)) }
            )
        ]
    }

    /// After an update: in the notifications, and under the notch until swiped up (spec U-5).
    /// Shown once the notch exists, so it really appears.
    private func announceUpdate() {
        guard let previous = services.updates.versionUpdatedFrom() else { return }
        DiagnosticsLog.append("updates", "now running \(AppInfo.version), updated from \(previous)")
        let notifications = services.notifications
        let notices = services.notices
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            notifications.present(
                title: "Dynotch updated", body: "Version \(AppInfo.version) is running.", appIdentifier: AppInfo.bundleIdentifier
            )
            notices.show(StickyNotice(
                title: "Dynotch updated", detail: "Version \(AppInfo.version)", date: Date(), symbol: "arrow.down.circle.fill"
            ))
        }
    }

    /// "New Dynotch Note" in the Services menu (spec J-13).
    private func offerTextService(_ manager: NotchManager) {
        let provider = TextServiceProvider { [weak self, weak manager] text in
            self?.services.notes.addToScratchpad(text)
            manager?.open(.notes, pinned: true)
        }
        textService = provider
        NSApp.servicesProvider = provider
        NSUpdateDynamicServices()
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
