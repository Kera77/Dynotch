@testable import Dynotch
import Foundation
import Testing

/// Merging Batteries into System and AI Usage into AI (spec MG-1…MG-8).
@MainActor
struct MergedModulesTests {
    private func makeSettings() -> (AppSettings, UserDefaults) {
        let name = "MergedModulesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return (AppSettings(defaults: defaults), defaults)
    }

    @Test func batteriesAndUsageAreAlwaysTabs() {
        let (settings, _) = makeSettings()
        #expect(!settings.listedFeatures.contains(.battery))
        #expect(!settings.listedFeatures.contains(.claudeUsage))
        #expect(settings.mergedTabs(for: .stats) == [.stats, .battery])
        #expect(settings.mergedTabs(for: .claudeUsage) == [.claudeChat, .claudeUsage])
        #expect(settings.hostFeature(of: .claudeUsage) == .claudeChat)
        #expect(!settings.isMerged(.calendar))
    }

    @Test func aTabRunsWhileItsHostIsOn() {
        let (settings, _) = makeSettings()
        settings.setEnabled(.stats, false)
        #expect(!settings.isEnabled(.battery))
        settings.setEnabled(.stats, true)
        #expect(settings.isEnabled(.battery))
    }

    @Test func aTabTakesItsHostsPlaceAmongThePages() {
        let listed: [FeatureID] = [.calendar, .stats, .notes]
        #expect(NotchView.pages(listed: listed, current: .battery, host: .stats) == [.calendar, .battery, .notes])
        #expect(NotchView.pages(listed: listed, current: .music, host: .music) == [.calendar, .stats, .notes, .music])
        #expect(NotchView.pages(listed: listed, current: .notes, host: .notes) == listed)
    }
}
