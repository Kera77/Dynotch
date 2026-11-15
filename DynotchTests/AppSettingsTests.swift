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
        #expect(settings.setEnabled(.info, false))
        #expect(settings.setEnabled(.calendar, false))
        #expect(settings.setEnabled(.notifications, false))
        #expect(!settings.setEnabled(.home, false))
        #expect(settings.activeFeatures == [.home])
    }

    @Test func reorderIsPersisted() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.moveFeatures(from: IndexSet(integer: 3), to: 0)
        #expect(settings.featureOrder == [.info, .home, .calendar, .notifications])
        #expect(AppSettings(defaults: defaults).featureOrder == [.info, .home, .calendar, .notifications])
    }

    /// Users upgrading from a version without a feature get it appended and enabled.
    @Test func newFeatureIsAppendedAndEnabledForExistingUsers() {
        let defaults = makeDefaults()
        defaults.set(["info", "home"], forKey: "featureOrder")
        defaults.set(["home"], forKey: "enabledFeatures")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.featureOrder == [.info, .home, .calendar, .notifications])
        #expect(settings.activeFeatures == [.home, .calendar, .notifications])
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
}
