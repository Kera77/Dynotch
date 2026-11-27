import Foundation
import SwiftUI
import Testing
@testable import Wingmate

/// Designs, blur, panel opacity and the pill (spec D-1…D-7).
@MainActor
struct DesignTests {
    private func makeDefaults() -> UserDefaults {
        let name = "DesignTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func blackIsTheDefaultDesignAndTheChoiceIsKept() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        #expect(settings.design == .black)
        #expect(settings.keepsPhoneInDock)
        settings.design = .blend
        #expect(AppSettings(defaults: defaults).design == .blend)
        #expect(NotchDesign.allCases.map(\.title) == ["Black", "Liquid glass", "Black to glass", "Black over glass"])
    }

    @Test func blurFollowsTheDesign() {
        #expect(DesignBackground<Rectangle>.blurOpacity(glass: false, isOpen: true, openOpacity: 1) == 0)
        #expect(abs(DesignBackground<Rectangle>.blurOpacity(glass: false, isOpen: true, openOpacity: 0.4) - 0.55) < 0.0001)
        #expect(DesignBackground<Rectangle>.blurOpacity(glass: true, isOpen: true, openOpacity: 1) > 0.5)
        #expect(DesignBackground<Rectangle>.blurOpacity(glass: true, isOpen: false, openOpacity: 1) == 0)
    }

    @Test @MainActor func externalDisplaysShowANotchByDefault() {
        let name = "DesignTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: defaults)
        #expect(settings.externalStyle == .notch)
        settings.externalStyle = .pill
        #expect(AppSettings(defaults: defaults).externalStyle == .pill)
    }

    @MainActor @Test func panelOpacityStaysBetweenFortyAndHundredPercent() throws {
        let defaults = try #require(UserDefaults(suiteName: "DesignTests-\(UUID().uuidString)"))
        #expect(AppSettings(defaults: defaults).panelOpacity == 1)
        defaults.set(0.1, forKey: "panelOpacity")
        #expect(AppSettings(defaults: defaults).panelOpacity == 0.4)
        let settings = AppSettings(defaults: defaults)
        settings.panelOpacity = 0.7
        #expect(abs(AppSettings(defaults: defaults).panelOpacity - 0.7) < 0.0001)
    }
}
