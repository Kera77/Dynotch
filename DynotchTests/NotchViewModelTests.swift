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

    /// Spec E-4: opening from a notification peek shows the notifications without changing
    /// which feature is remembered.
    @Test func openingFromPeekDoesNotChangeRememberedFeature() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.calendar)
        model.setExpanded(false)

        model.setExpanded(true, showing: .notifications)
        #expect(model.currentFeature == .notifications)
        model.setExpanded(false)

        model.setExpanded(true)
        #expect(model.currentFeature == .calendar)
    }
}
