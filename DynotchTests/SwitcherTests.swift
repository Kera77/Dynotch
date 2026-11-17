import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// Spec M-9: only the icons that fit beside the notch are shown; a swipe moves them.
@MainActor
struct SwitcherTests {
    private func makeModel() -> NotchViewModel {
        let name = "SwitcherTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        // A 14" MacBook Pro: the panel is 560 wide, the notch about 185.
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663, auxiliaryRightWidth: 664, menuBarHeight: 32
        )
        return NotchViewModel(settings: AppSettings(defaults: defaults), geometry: geometry, screenName: "Test")
    }

    @Test func onlyWhatFitsIsShown() {
        #expect(FeatureSwitcher.visibleCount(for: 176) == 5)
        #expect(FeatureSwitcher.visibleCount(for: 20) == 1)
        #expect(FeatureSwitcher.clampedFirst(-3, count: 10, visible: 5) == 0)
        #expect(FeatureSwitcher.clampedFirst(9, count: 10, visible: 5) == 5)
        #expect(FeatureSwitcher.clampedFirst(4, count: 3, visible: 5) == 0)

        let model = makeModel()
        model.setExpanded(true)
        let visible = model.switcherVisibleCount
        // Never wider than the room left of the notch.
        let room = (model.openSize.width - model.geometry.notchSize.width) / 2 - 22
        #expect(CGFloat(visible) * FeatureSwitcher.step - FeatureSwitcher.spacing + 6 <= room)
        #expect(visible < FeatureID.allCases.count)
    }

    @Test func aSwipeMovesTheIconsButNotTheFeature() {
        let model = makeModel()
        model.select(.home)
        model.setExpanded(true)
        let feature = model.currentFeature
        model.scrollSwitcher(by: 2)
        #expect(model.switcherFirst == 2)
        #expect(model.currentFeature == feature)
        model.scrollSwitcher(by: 100)
        #expect(model.switcherFirst == FeatureID.allCases.count - model.switcherVisibleCount)
        model.scrollSwitcher(by: -100)
        #expect(model.switcherFirst == 0)
    }

    @Test func theCurrentFeatureIsBroughtIntoView() {
        let model = makeModel()
        model.setExpanded(true)
        let last = model.settings.activeFeatures.last ?? .info
        model.select(last)
        #expect(model.switcherFirst == model.settings.activeFeatures.count - model.switcherVisibleCount)
        model.select(model.settings.activeFeatures[0])
        #expect(model.switcherFirst == 0)
    }

    /// Spec B-6: the badge's list holds only that app's notifications, also after removals.
    @Test func theBadgeListShowsOnlyThatApp() {
        let name = "SwitcherTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let service = NotificationService(settings: AppSettings(defaults: defaults))
        service.present(title: "Anna", body: "chat", appIdentifier: "com.apple.safari.webapp.abc")
        service.present(title: "Bob", body: "beeper", appIdentifier: "com.automattic.beeper.desktop")
        service.setFocus(bundleID: "com.apple.Safari.WebApp.ABC", name: "Google Chat", count: 5)
        #expect(service.focus?.notifications.map(\.body) == ["chat"])
        let token = service.focus?.token
        service.setFocus(bundleID: "com.apple.Safari.WebApp.ABC", name: "Google Chat", count: 5)
        #expect(service.focus?.token != token)
        service.clearPeek()
    }
}
