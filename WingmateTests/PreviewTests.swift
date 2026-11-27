import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

/// The preview on hover (spec PV-1…PV-3, PV-8).
@MainActor
struct PreviewTests {
    private func makeDefaults() -> UserDefaults {
        let name = "PreviewTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func thePreviewIsSmallAndGivesWayToTheFullPanel() {
        let settings = AppSettings(defaults: makeDefaults())
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663, auxiliaryRightWidth: 664, menuBarHeight: 32
        )
        let model = NotchViewModel(settings: settings, geometry: geometry, screenName: "Test")
        model.setPreview(true)
        #expect(!model.isPreview)

        model.setExpanded(true)
        model.setPreview(true)
        #expect(model.isPreview)
        #expect(model.openSize == geometry.wingsSize(model.wingsSides))
        #expect(model.openSize.height == geometry.notchSize.height)
        // As wide as the content needs, never beyond two thirds of the display (spec PV-8).
        #expect(geometry.previewSize(side: 10_000).width <= geometry.screenFrame.width * 2 / 3)
        #expect(geometry.previewSize(side: 0).width == geometry.notchSize.width + 2 * NotchGeometry.previewMinSide)
        #expect(!model.wantsKeyboard)

        model.select(.calculator)
        #expect(!model.isPreview)
        #expect(model.openSize == geometry.expandedSize)

        model.setPreview(true)
        model.setExpanded(false)
        #expect(!model.isPreview)
    }

    @Test func previewSettings() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        #expect(!settings.hoverPreview)
        settings.hoverPreview = true
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.hoverPreview)
        #expect(AppSettings.menuBarFeatures.contains(.claudeChat))

        #expect(FeaturePreview.line(of: "\n  first \nsecond", fallback: "-") == "first")
        #expect(FeaturePreview.line(of: "1+1\n= 2\n", fallback: "-", last: true) == "= 2")
        #expect(FeaturePreview.line(of: " \n", fallback: "Empty") == "Empty")
        #expect(FeaturePreview.line(of: String(repeating: "a", count: 90), fallback: "-").count == 71)
    }
}
