@testable import Dynotch
import Foundation
import Testing

@MainActor
struct AppSettingsTests {
    private func makeDefaults() -> UserDefaults {
        let name = "DynotchTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaults() {
        let settings = AppSettings(defaults: makeDefaults())
        #expect(settings.closeDelay == AppSettings.defaultCloseDelay)
        #expect(settings.activeFeatures == FeatureID.allCases)
        #expect(settings.initialFeature == FeatureID.allCases[0])
    }

    @Test func closeDelayIsClampedAndRounded() {
        let settings = AppSettings(defaults: makeDefaults())
        settings.closeDelay = 7
        #expect(settings.closeDelay == 3)
        settings.closeDelay = 0.4499
        #expect(settings.closeDelay == 0.4)
        settings.closeDelay = -1
        #expect(settings.closeDelay == 0)
    }

    @Test func lastFeatureIsPersisted() {
        let defaults = makeDefaults()
        AppSettings(defaults: defaults).lastFeature = .info
        #expect(AppSettings(defaults: defaults).initialFeature == .info)
    }

    @Test func disabledLastFeatureFallsBackToFirstEnabled() {
        let settings = AppSettings(defaults: makeDefaults())
        settings.lastFeature = .info
        settings.setEnabled(.info, false)
        #expect(settings.initialFeature == .home)
    }

    @Test func lastEnabledFeatureCannotBeDisabled() {
        let settings = AppSettings(defaults: makeDefaults())
        for feature in FeatureID.allCases where feature != .home {
            #expect(settings.setEnabled(feature, false))
        }
        #expect(!settings.setEnabled(.home, false))
        #expect(settings.activeFeatures == [.home])
    }

    @Test func reorderIsPersisted() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        let last = FeatureID.allCases.count - 1
        let expected = [FeatureID.allCases[last]] + FeatureID.allCases.dropLast()
        settings.moveFeatures(from: IndexSet(integer: last), to: 0)
        #expect(settings.featureOrder == expected)
        #expect(AppSettings(defaults: defaults).featureOrder == expected)
    }

    /// Users upgrading from a version without a feature get it appended and enabled.
    @Test func newFeatureIsAppendedAndEnabledForExistingUsers() {
        let defaults = makeDefaults()
        defaults.set(["info", "home"], forKey: "featureOrder")
        defaults.set(["home"], forKey: "enabledFeatures")
        let settings = AppSettings(defaults: defaults)
        let added = FeatureID.allCases.filter { $0 != .info && $0 != .home }
        #expect(settings.featureOrder == [.info, .home] + added)
        #expect(settings.activeFeatures == [.home] + added)
    }

    @Test func calendarLeadMinutesIsClamped() {
        let settings = AppSettings(defaults: makeDefaults())
        #expect(settings.calendarLeadMinutes == AppSettings.defaultCalendarLeadMinutes)
        settings.calendarLeadMinutes = 99
        #expect(settings.calendarLeadMinutes == 30)
        settings.calendarLeadMinutes = 0
        #expect(settings.calendarLeadMinutes == 1)
    }

    @Test func notificationSettingsArePersisted() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        #expect(settings.notificationDuration == AppSettings.defaultNotificationDuration)
        settings.notificationDuration = 99
        #expect(settings.notificationDuration == 30)
        #expect(settings.isNotificationAppEnabled("com.example", default: true))
        settings.setNotificationApp("com.example", enabled: false)

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.notificationDuration == 30)
        #expect(!reloaded.isNotificationAppEnabled("com.example", default: true))
        #expect(reloaded.isNotificationAppEnabled("com.other", default: true))
    }

    @Test func settingsOpenInNotchByDefault() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        #expect(settings.settingsPresentation == .notch)
        settings.settingsPresentation = .window
        #expect(AppSettings(defaults: defaults).settingsPresentation == .window)
    }

    /// Spec M-6: reordering in the menu bar keeps disabled features in place.
    @Test func moveActiveFeatureKeepsDisabledInPlace() {
        let settings = AppSettings(defaults: makeDefaults())
        settings.featureOrder = [.home, .info, .calendar, .notes]
        settings.setEnabled(.info, false)
        #expect(settings.activeFeatures.prefix(3) == [.home, .calendar, .notes])

        settings.moveActiveFeature(.notes, toActiveIndex: 0)
        #expect(Array(settings.featureOrder.prefix(4)) == [.notes, .info, .home, .calendar])
        #expect(settings.activeFeatures.prefix(3) == [.notes, .home, .calendar])

        settings.moveActiveFeature(.notes, toActiveIndex: 99)
        #expect(settings.activeFeatures.last == .notes)
        #expect(settings.featureOrder[1] == .info)
    }

    @Test func dragTargetIndex() {
        #expect(FeatureSwitcher.targetIndex(from: 2, offset: 0, count: 5) == 2)
        #expect(FeatureSwitcher.targetIndex(from: 2, offset: 34, count: 5) == 3)
        #expect(FeatureSwitcher.targetIndex(from: 2, offset: -50, count: 5) == 1)
        #expect(FeatureSwitcher.targetIndex(from: 2, offset: -500, count: 5) == 0)
        #expect(FeatureSwitcher.targetIndex(from: 2, offset: 500, count: 5) == 4)
    }

    /// Spec M-6: while dragging, the icons between the start and the drop place move aside.
    @Test func dragShiftsTheIconsInBetween() {
        let step = FeatureSwitcher.step
        // Dragging index 1 to index 3: icons 2 and 3 move left.
        #expect((0..<5).map { FeatureSwitcher.shift(of: $0, draggedFrom: 1, to: 3) } == [0, 0, -step, -step, 0])
        // Dragging index 3 to index 0: icons 0…2 move right.
        #expect((0..<5).map { FeatureSwitcher.shift(of: $0, draggedFrom: 3, to: 0) } == [step, step, step, 0, 0])
        #expect((0..<5).map { FeatureSwitcher.shift(of: $0, draggedFrom: 2, to: 2) } == [0, 0, 0, 0, 0])
    }

    @Test func focusFollowsMouseSettings() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        #expect(settings.focusFollowsMouse)
        #expect(settings.focusDelay == 0.1)
        settings.focusDelay = 2
        #expect(settings.focusDelay == AppSettings.focusDelayRange.upperBound)
        settings.focusFollowsMouse = false
        #expect(!AppSettings(defaults: defaults).focusFollowsMouse)
    }

    /// Spec M-7: menu bar icons can be turned off per feature.
    @Test func menuBarVisibilityPerFeature() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        #expect(settings.showsInMenuBar(.notes))
        #expect(!settings.showsInMenuBar(.calendar))
        settings.setShowsInMenuBar(.notes, false)
        #expect(!settings.showsInMenuBar(.notes))
        #expect(!AppSettings(defaults: defaults).showsInMenuBar(.notes))
        #expect(AppSettings(defaults: defaults).showsInMenuBar(.reminders))
    }
}
