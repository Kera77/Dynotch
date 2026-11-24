import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    private lazy var notifications = NotificationService(settings: settings)
    private lazy var clipboard = ClipboardStore()
    private lazy var reminders = RemindersStore()
    private lazy var services = AppServices(
        settings: settings,
        calendar: CalendarService(settings: settings),
        notifications: notifications,
        calculator: CalculatorStore(),
        notes: NotesStore(),
        reminders: reminders,
        tasks: TaskIndicator(store: reminders),
        claudeUsage: ClaudeUsageService(settings: settings) { [notifications] title, body in
            notifications.present(title: title, body: body, appIdentifier: "com.anthropic.claudefordesktop", kind: .aiUsage)
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
        devices: DeviceWatcher(settings: settings),
        switcher: SwitcherController(settings: SwitcherSettings()),
        music: MusicService(settings: settings),
        stats: StatsService(settings: settings),
        screenshots: ScreenshotService(settings: ScreenshotSettings())
    )
    private lazy var settingsWindow = SettingsWindowController(
        services: services
    )
    private var notchManager: NotchManager?
    private var textService: TextServiceProvider?
    private var switcherObserver: ChangeObservation?
    private var screenshotObserver: ChangeObservation?
    /// Keeps App Nap away: after a long idle time the first opening of the notch lagged while the
    /// app woke up (spec N-14). Idle system sleep is still allowed.
    private let noNap = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiatedAllowingIdleSystemSleep], reason: "The notch reacts to the pointer at once"
    )
    private var hotkeys: HotkeyCenter?
    /// A finished download shows beside the notch (spec PV-57) and goes into the tray (spec FT-15).
    private lazy var downloadWatcher = DownloadWatcher { [notices = services.notices, tray = services.tray, settings] file in
        if settings.isEnabled(.tray) { tray.addDownload(file) }
        notices.showDownload(file)
    }
    private var menuBarPanels: [MenuBarPopoverController] = []
    private lazy var focusFollowsMouse = FocusFollowsMouse(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app host; don't put a panel on screen there.
        guard !AppInfo.isRunningTests else { return }

        // Sleep, lock and power pause or slow every background look (spec RF-9, RF-10).
        PowerMonitor.shared.start()
        services.calendar.start()
        services.notifications.start()
        // Loads the open count for the menu bar icon if access was granted before; never prompts.
        services.reminders.start()
        focusFollowsMouse.start()
        services.claudeUsage.start()
        services.hud.start()
        startBadges()
        MenuBarSpacerService.shared.start()
        MenuBarTintService.shared.start()
        services.calls.start()
        ClaudeHook.upgradeIfNeeded()
        ClaudeQuestionHook.upgradeIfNeeded()
        startDeviceAndMediaModules()
        services.updates.start()
        let notices = services.notices
        services.chat.onAnswerReady = { chat in
            notices.show(.answered(by: chat.service.title, in: chat.title))
        }
        showsReplyProblems(services.notifications.chatWeb, in: notices)
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
        startSwitcher(manager)
        startScreenshots(manager)
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
                badge: Badge { reminders.access == .granted ? reminders.openCount : nil },
                onOpen: { reminders.activate() },
                makeContent: { AnyView(RemindersMenuBarView(store: reminders, state: $0)) }
            ),
            MenuBarPopoverController(
                feature: .claudeUsage,
                panelSize: NSSize(width: 340, height: 300),
                settings: settings,
                icon: StatusIcon(
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
                icon: StatusIcon(image: { nil }, toolTip: { "AI" }),
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
            guard notifications.preferences.isOn(.updates) else { return }
            notifications.present(
                title: "Dynotch updated", body: "Version \(AppInfo.version) is running.", appIdentifier: AppInfo.bundleIdentifier,
                kind: .updates
            )
            notices.show(StickyNotice(
                title: "Dynotch updated", detail: "Version \(AppInfo.version)", date: Date(), symbol: "arrow.down.circle.fill"
            ))
        }
    }

    /// The window switcher: its shortcut and the trackpad swipe (spec AS-8, AS-11).
    private func startSwitcher(_ manager: NotchManager) {
        let switcher = services.switcher
        switcher.present = { [weak manager] shown in manager?.showSwitcher(shown) }
        switcher.displayFrame = { NotchManager.pointerDisplayFrame() }
        switcher.start()
        startModuleSwitcher(manager)
        let follow: @MainActor @Sendable () -> Void = {
            let settings = switcher.settings
            TrackpadSwipe.fingers = settings.isOn ? settings.swipeFingers : 0
            TrackpadSwipe.upFingers = settings.moduleSwitcherOn ? settings.moduleFingers : 0
            // The trackpad is only listened to while a switcher uses it (spec AS-12, QS-1).
            guard TrackpadSwipe.fingers > 0 || TrackpadSwipe.upFingers > 0 else { return }
            let modules = switcher.modules
            TrackpadSwipe.start { event in
                MainActor.assumeIsolated {
                    // Moves and ends go to both: each acts only on its own gesture.
                    switch event {
                    case .began(.sideways): switcher.swipeBegan()
                    case .began(.upward): modules.swipeBegan()
                    case .moved(let travel):
                        switcher.swipeMoved(travel: travel)
                        modules.swipeMoved(travel: travel)
                    case .ended(let cancelled):
                        switcher.swipeEnded(cancelled: cancelled)
                        modules.swipeEnded(cancelled: cancelled)
                    }
                }
            }
        }
        follow()
        switcherObserver = observeChanges { [settings = switcher.settings] in
            _ = (settings.isOn, settings.swipeFingers, settings.moduleSwitcherOn, settings.moduleFingers)
        } onChange: { follow() }
    }

    /// The module switcher: the chosen modules, opened like their shortcut (spec QS-6, QS-10).
    private func startModuleSwitcher(_ manager: NotchManager) {
        let modules = services.switcher.modules
        let shortcuts = services.shortcuts
        let settings = services.settings
        modules.settings.seedModuleRow(settings.activeFeatures.filter { shortcuts.shortcuts[$0] != nil })
        // The chosen modules in the row's order, those that are off too (spec QS-15); a merged
        // module stands on its host's tab (spec MG-9).
        modules.candidates = { [weak modules] in
            modules?.settings.moduleRow.filter { !settings.isMerged($0) || settings.isSwitchedOn($0) } ?? []
        }
        modules.present = { [weak manager] shown in manager?.showModuleSwitcher(shown) }
        modules.open = { [weak manager] in manager?.openFromModuleSwitcher($0, pinned: shortcuts.pinsWhenOpened($0)) }
        modules.onStep = { Haptics.perform(.featureSwitch, settings: settings) }
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

    /// Batteries, music, the stats and screenshots, with their own notifications.
    private func startDeviceAndMediaModules() {
        downloadWatcher.start()
        services.battery.onCharged = { [notifications] device in
            notifications.present(
                title: "\(device.name) is charged", body: "100%", appIdentifier: AppInfo.bundleIdentifier, kind: .batteries
            )
        }
        services.battery.start()
        services.music.start()
        services.stats.notify = { [notifications] title, body in
            notifications.present(title: title, body: body, appIdentifier: AppInfo.bundleIdentifier, kind: .swap)
        }
        services.stats.isAlertOff = { [notifications] alert in
            switch alert {
            case .memory: !notifications.preferences.isOn(.memory)
            case .swap: !notifications.preferences.isOn(.swap)
            case .disk, .heat: !notifications.preferences.isOn(.system)
            }
        }
        services.stats.start()
        services.screenshots.start()
    }
}

extension AppDelegate {
    /// The badges beside the notch, with Gmail's count from Mail (spec GM-7) and the highlighted
    /// Beeper networks' badges of their own (spec BP-14).
    func startBadges() {
        services.badges.labelOverride = { [weak notifications = services.notifications] app in
            notifications?.mailBadgeLabel(for: app) ?? notifications?.chatBadgeLabel(for: app)
        }
        services.badges.beeperNetworks = { [weak beeper = services.beeper] in beeper?.highlightedNetworks ?? [] }
        services.badges.beeperNetworkUnread = { [weak beeper = services.beeper] in beeper?.unreadTotal(network: $0) ?? 0 }
        services.badges.removeBeeperNetwork = { [weak beeper = services.beeper] in beeper?.setHighlighted($0, false) }
        services.badges.start()
    }
}

extension AppDelegate {
    /// A Google Chat reply that went out in the background but never showed up (spec GW-31).
    func showsReplyProblems(_ chatWeb: GoogleChatWebService, in notices: NoticeService) {
        chatWeb.onReplyProblem = { problem in
            notices.show(StickyNotice(
                title: "Google Chat", detail: problem, date: Date(), symbol: "exclamationmark.bubble.fill", sourceName: "Google Chat"
            ))
        }
    }
}

extension AppDelegate {
    fileprivate func startScreenshots(_ manager: NotchManager) {
        services.screenshots.openEditor = { [weak manager] url in manager?.openScreenshotEditor(url) }
        // The tray's Screenshots tab follows the tool (spec SH-11).
        let screenshotSettings = services.screenshots.settings
        services.tray.showsScreenshots = screenshotSettings.isOn
        screenshotObserver = observeChanges { _ = screenshotSettings.isOn } onChange: { [tray = services.tray] in
            tray.showsScreenshots = screenshotSettings.isOn
        }
    }
}
