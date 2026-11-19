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

    @Test func nothingIsMergedByDefault() {
        let (settings, _) = makeSettings()
        #expect(settings.listedFeatures.contains(.battery))
        #expect(settings.listedFeatures.contains(.claudeUsage))
        #expect(settings.mergedTabs(for: .stats) == nil)
    }

    @Test func aMergedModuleLeavesTheListAndBecomesATab() {
        let (settings, defaults) = makeSettings()
        settings.setMerged(.claudeUsage, true)
        #expect(!settings.listedFeatures.contains(.claudeUsage))
        #expect(settings.listedFeatures.contains(.battery))
        #expect(settings.mergedTabs(for: .claudeChat) == [.claudeChat, .claudeUsage])
        #expect(settings.mergedTabs(for: .claudeUsage) == [.claudeChat, .claudeUsage])
        #expect(settings.hostFeature(of: .claudeUsage) == .claudeChat)
        #expect(AppSettings(defaults: defaults).isMerged(.claudeUsage))
        settings.setMerged(.calendar, true)
        #expect(!settings.isMerged(.calendar))
    }

    @Test func aMergedModuleRunsWhileItsHostIsOnAndKeepsItsOwnState() {
        let (settings, _) = makeSettings()
        settings.setEnabled(.battery, false)
        settings.setMerged(.battery, true)
        #expect(settings.isEnabled(.battery))
        settings.setEnabled(.stats, false)
        #expect(!settings.isEnabled(.battery))
        settings.setEnabled(.stats, true)
        settings.setMerged(.battery, false)
        #expect(!settings.isEnabled(.battery))
        #expect(!settings.listedFeatures.contains(.battery))
    }

    @Test func aTabTakesItsHostsPlaceAmongThePages() {
        let listed: [FeatureID] = [.calendar, .stats, .notes]
        #expect(NotchView.pages(listed: listed, current: .battery, host: .stats) == [.calendar, .battery, .notes])
        #expect(NotchView.pages(listed: listed, current: .music, host: .music) == [.calendar, .stats, .notes, .music])
        #expect(NotchView.pages(listed: listed, current: .notes, host: .notes) == listed)
    }
}
