import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

/// The module strip under the notch (spec MS-1…MS-4).
@MainActor
struct ModuleStripTests {
    @Test func theStripSitsCentredUnderTheNotch() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663, auxiliaryRightWidth: 664, menuBarHeight: 32
        )
        let strip = geometry.moduleStripRect(count: 5)
        #expect(abs(strip.midX - geometry.notchRect.midX) < 0.001)
        #expect(abs(strip.maxY - (geometry.notchRect.minY - NotchGeometry.stripGap)) < 0.001)
        #expect(abs(strip.width - (5 * NotchGeometry.stripIconSize + 4 * NotchGeometry.stripSpacing)) < 0.001)
    }

    @Test func stripDefaults() {
        let name = "ModuleStripTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: defaults)
        #expect(settings.moduleStrip)
        #expect(abs(settings.moduleStripDelay - 0.3) < 0.001)
        #expect(abs(settings.moduleStripBand - 0.5) < 0.001)
        #expect(SmartRule.allCases.allSatisfy(settings.isSmartRuleOn))
        settings.setSmartRule(.usage, enabled: false)
        #expect(!AppSettings(defaults: defaults).isSmartRuleOn(.usage))
    }

    @Test func stripHoverSettingIsKept() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let settings = AppSettings(defaults: defaults)
        #expect(!settings.moduleStripHover)
        #expect(settings.moduleStripHoverDelay == 0.5)
        settings.moduleStripHover = true
        settings.moduleStripHoverDelay = 0.8
        let again = AppSettings(defaults: defaults)
        #expect(again.moduleStripHover)
        #expect(again.moduleStripHoverDelay == 0.8)
    }
}
