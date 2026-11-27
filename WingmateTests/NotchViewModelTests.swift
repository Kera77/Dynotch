import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

@MainActor
struct NotchViewModelTests {
    private func makeModel() -> NotchViewModel {
        let name = "WingmateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        return NotchViewModel(settings: AppSettings(defaults: defaults), geometry: geometry, screenName: "Test")
    }

    @Test func largeSizeOnlyForOpenCalendar() {
        let model = makeModel()
        model.setExpanded(true)
        model.setCalendarLarge(true)
        #expect(!model.isLarge)

        model.select(.calendar)
        #expect(model.isLarge)
        #expect(model.openSize == model.geometry.largeSize)

        model.select(.home)
        #expect(!model.isLarge)
        #expect(model.openSize == model.geometry.expandedSize)
    }

    /// Spec K-10: the calendar reopens in the view it was closed in.
    @Test func largeCalendarIsRememberedAcrossReopen() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.calendar)
        model.setCalendarLarge(true)
        model.setExpanded(false)
        #expect(!model.isLarge)

        model.setExpanded(true)
        #expect(model.currentFeature == .calendar)
        #expect(model.isLarge)

        model.setCalendarLarge(false)
        model.setExpanded(false)
        model.setExpanded(true)
        #expect(!model.isLarge)
    }

    /// Spec E-4, E-11: opening from a peek lists the new notifications in their own size, with
    /// the keyboard only when a reply is possible; the remembered feature is untouched.
    @Test func openingFromPeekListsTheNewNotifications() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.calendar)
        model.setExpanded(false)

        let stack = (1...3).map {
            AppNotification(
                id: Int64($0), appIdentifier: "com.automattic.beeper.desktop",
                title: "Anna", subtitle: "", body: "\($0)", date: Date()
            )
        }
        model.setExpanded(true, presenting: stack, canReply: true)
        #expect(model.notifications == stack)
        #expect(model.notificationsCanReply)
        #expect(model.openSize == model.geometry.notificationSize(count: 3, hasReply: true))
        #expect(model.wantsKeyboard)
        model.setExpanded(false)
        #expect(!model.isShowingNotifications)

        model.setExpanded(true, presenting: stack, canReply: false)
        #expect(!model.wantsKeyboard)
        #expect(model.openSize == model.geometry.notificationSize(count: 3, hasReply: true))
        model.setExpanded(false)

        model.setExpanded(true)
        #expect(!model.isShowingNotifications)
        #expect(model.currentFeature == .calendar)
        #expect(model.openSize == model.geometry.expandedSize)
    }

    /// Spec C-11: settings over the wide Beeper tab still get their own height, so the top row
    /// stays in sight.
    @Test func settingsOverWideChatTabKeepTheirSize() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.notifications)
        model.notificationsTab = .beeper
        model.setShowingSettings(true)
        #expect(model.openSize == model.geometry.settingsSize)
    }

    /// Spec C-2: settings in the notch use their own size and end when a feature is picked
    /// or the panel closes.
    @Test func settingsInNotch() {
        let model = makeModel()
        model.setShowingSettings(true)
        #expect(!model.isShowingSettings)

        model.setExpanded(true)
        model.setShowingSettings(true)
        #expect(model.isShowingSettings)
        #expect(model.openSize == model.geometry.settingsSize)

        model.select(model.currentFeature)
        #expect(!model.isShowingSettings)
        #expect(model.openSize == model.geometry.expandedSize)

        model.setShowingSettings(true)
        model.setExpanded(false)
        model.setExpanded(true)
        #expect(!model.isShowingSettings)
    }

    @Test func settingsHideLargeCalendar() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.calendar)
        model.setCalendarLarge(true)
        model.setShowingSettings(true)
        #expect(!model.isLarge)
        model.setShowingSettings(false)
        #expect(model.isLarge)
    }

    /// Spec SZ-1, SZ-8: keyboard focus only for the calculator and the settings; closing unpins.
    @Test func keyboardAndPin() {
        let model = makeModel()
        #expect(!model.wantsKeyboard)
        model.setExpanded(true)
        #expect(!model.wantsKeyboard)
        model.select(.calculator)
        #expect(model.wantsKeyboard)
        model.select(.home)
        model.setShowingSettings(true)
        #expect(model.wantsKeyboard)

        model.isPinned = true
        model.setExpanded(false)
        #expect(!model.isPinned)
        #expect(!model.wantsKeyboard)
    }

    /// Spec J-1: the notes use the large panel and take the keyboard.
    @Test func notesUseLargePanelAndKeyboard() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.notes)
        #expect(model.isLarge)
        #expect(model.wantsKeyboard)
        #expect(model.openSize == model.geometry.mediumSize)
        model.select(.reminders)
        #expect(model.isLarge)
        #expect(model.wantsKeyboard)
        model.select(.home)
        #expect(!model.isLarge)
    }

    /// Spec CL-3: the AI Usage panel is tall enough for every limit.
    @Test func aiUsageHasItsOwnSize() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.claudeUsage)
        #expect(model.openSize.height == model.geometry.usageSize.height)
        #expect(model.openSize.height > model.geometry.expandedSize.height)
        #expect(model.geometry.windowSize.height >= model.openSize.height)
    }

    @Test func shortcutModuleIsNotRememberedForHover() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.calendar)
        model.select(.calculator, remember: false)
        #expect(model.currentFeature == .calculator)
        model.setExpanded(false)
        model.setExpanded(true)
        #expect(model.currentFeature == .calendar)
    }
}
