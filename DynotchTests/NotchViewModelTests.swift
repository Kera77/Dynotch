import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

@MainActor
struct NotchViewModelTests {
    private func makeModel() -> NotchViewModel {
        let name = "DynotchTests-\(UUID().uuidString)"
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

    /// Spec E-4: opening from a notification peek shows only that notification, in its own
    /// size, and does not change which feature is remembered.
    @Test func openingFromPeekShowsOnlyThatNotification() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.calendar)
        model.setExpanded(false)

        let notification = AppNotification(id: 7, appIdentifier: "app", title: "Anna", subtitle: "", body: "Szia", date: Date())
        model.setExpanded(true, presenting: notification)
        #expect(model.notification == notification)
        #expect(model.openSize == model.geometry.notificationSize)
        #expect(!model.wantsKeyboard)
        model.setExpanded(false)
        #expect(model.notification == nil)

        model.setExpanded(true)
        #expect(model.notification == nil)
        #expect(model.currentFeature == .calendar)
        #expect(model.openSize == model.geometry.expandedSize)
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
        #expect(model.openSize == model.geometry.largeSize)
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
        #expect(model.openSize == model.geometry.usageSize)
        #expect(model.openSize.height > model.geometry.expandedSize.height)
        #expect(model.geometry.windowSize.height >= model.openSize.height)
    }
}
