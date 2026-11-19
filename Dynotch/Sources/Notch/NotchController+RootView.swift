import AppKit
import SwiftUI

extension NotchController {
    /// The panel's SwiftUI content, wired to this controller.
    func makeRootView(_ services: AppServices) -> NotchView {
            var rootView = NotchView(
                model: model, settings: settings, calendar: calendar, calendarIndicator: calendar.indicator,
                notifications: notifications, calculator: services.calculator, notes: services.notes,
                reminders: services.reminders, tasks: services.tasks, claudeUsage: services.claudeUsage, hud: services.hud,
                badges: services.badges,
                calls: services.calls, keyboardLock: services.keyboardLock,
                notices: services.notices, chat: services.chat, chatIndicator: services.chat.indicator,
                battery: services.battery, shortcuts: services.shortcuts,
                updates: services.updates, tablets: services.tablets, clipboard: services.clipboard,
                clipboardPicker: services.clipboardPicker, tray: services.tray, beeper: services.beeper, devices: services.devices,
                musicIndicator: services.music.indicator, statsIndicator: services.stats.indicator, music: services.music,
                stats: services.stats, screenshots: services.screenshots
            ) { [weak self] in
                self?.settingsButtonPressed()
            }
            rootView.switcher = services.switcher
            rootView.closeNotifications = { [weak self] in self?.closeNotificationCard() }
            rootView.clearNotifications = { [weak self] in self?.clearAllNotifications() }
            rootView.openFully = { [weak self] in self?.openFully() }
            rootView.openModule = { [weak self] in self?.openFromStrip($0) }
            rootView.joinedMeeting = { [weak self] in self?.joinFromRow($0) }
            rootView.openNotice = { [weak self] in self?.openNoticeApp() }
            rootView.keepInTray = { [weak self] in self?.keepInTray($0) }
            rootView.sendWithAirDrop = { [weak self] in self?.sendWithAirDrop($0) }
            rootView.showBadgeNotifications = { [weak self] in self?.showNotifications(for: $0) }
        rootView.editScreenshot = { [weak self] in self?.openScreenshotEditor($0, fromPeek: false) }
        rootView.closeScreenshotEditor = { [weak self] in self?.closeScreenshotEditor() }
        return rootView
    }
}
