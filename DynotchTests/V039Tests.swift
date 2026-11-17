@testable import Dynotch
import Foundation
import Testing

/// v0.39: designs (spec D-1…D-5) and keeping the phone app in the Dock (spec P-5).
@MainActor
struct V039Tests {
    private func makeDefaults() -> UserDefaults {
        let name = "V039Tests-\(UUID().uuidString)"
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
        #expect(NotchDesign.allCases.map(\.title) == ["Black", "Liquid glass", "Black to glass"])
    }

    @Test func appearanceHasItsOwnTab() {
        #expect(SettingsTab.allCases.contains(.appearance))
        #expect(SettingsTab.appearance.title == "Appearance")
    }

    @Test func onlyThePhoneAppsAreHidden() {
        #expect(PhoneAppHider.identifiers == ["com.apple.FaceTime", "com.apple.mobilephone"])
    }
}
