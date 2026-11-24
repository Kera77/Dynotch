import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

@MainActor
struct V0102Tests {
    private func makeModel() -> NotchViewModel {
        let name = "V0102-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        return NotchViewModel(settings: AppSettings(defaults: defaults), geometry: geometry, screenName: "Test")
    }

    @Test func tabletMenuStaysBelowTheMenuBar() {
        let frame = CGRect(x: 100, y: 960, width: 30, height: 22)
        #expect(MenuAnchor.centred(below: frame, menuWidth: 200, visibleTop: 945).y == 945)
        #expect(MenuAnchor.centred(below: frame, menuWidth: 200, visibleTop: 990).y == 956)
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

    @Test func dynotchMenuOnScreenIsSeen() {
        let menu = ScreenWindow(id: 1, pid: 42, bounds: .zero, layer: FocusRules.popUpMenuLayer, alpha: 1)
        let panel = ScreenWindow(id: 2, pid: 42, bounds: .zero, layer: 27, alpha: 1)
        #expect(FocusRules.hasOpenMenu(in: [panel, menu], ownPID: 42))
        #expect(!FocusRules.hasOpenMenu(in: [panel], ownPID: 42))
        #expect(!FocusRules.hasOpenMenu(in: [menu], ownPID: 7))
    }
}
