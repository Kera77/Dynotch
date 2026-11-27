import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

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
        #expect(settings.mergedTabs(for: .claudeUsage) == [.claudeChat, .claudeUsage, .claudeSessions])
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

    private func makeModel() -> NotchViewModel {
        let name = "MergedModulesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        return NotchViewModel(settings: AppSettings(defaults: defaults), geometry: geometry, screenName: "Test")
    }

    @Test func systemOpensOnItsOwnTabUntilBatteriesIsPicked() {
        let model = makeModel()
        model.settings.setEnabled(.stats, true)
        #expect(model.lastTab(of: .stats) == .stats)
        // An alert showing Batteries does not change the tab picked by hand.
        model.select(.battery)
        #expect(model.lastTab(of: .stats) == .stats)
        model.pickTab(.battery)
        #expect(model.lastTab(of: .stats) == .battery)
        model.pickTab(.stats)
        #expect(model.lastTab(of: .stats) == .stats)
    }

    @Test func anOffModuleRunsOnlyWhileVisited() {
        let settings = makeModel().settings
        settings.setEnabled(.home, true)
        settings.setEnabled(.stats, false)
        #expect(!settings.isEnabled(.stats))
        settings.visitingFeature = .stats
        #expect(settings.isEnabled(.stats))
        #expect(settings.isEnabled(.battery))
        #expect(!settings.isSwitchedOn(.stats))
        settings.visitingFeature = nil
        #expect(!settings.isEnabled(.stats))
    }
}
