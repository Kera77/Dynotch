import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// The notch panel's controller: gathering on a Space switch, shrinking (spec N-8).
@MainActor
struct NotchControllerTests {
    private func makeDefaults() -> UserDefaults {
        let name = "NotchControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    /// Spec N-8: the Space switch draws everything into the notch and lets it unfold again.
    @Test func gatheringIsOnlyAState() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663, auxiliaryRightWidth: 664, menuBarHeight: 32
        )
        let model = NotchViewModel(settings: AppSettings(defaults: makeDefaults()), geometry: geometry, screenName: "Test")
        #expect(!model.isGathered)
        model.setGathered(true)
        #expect(model.isGathered)
        model.setGathered(false)
        #expect(!model.isGathered)
        #expect(NotchController.gatherTimeout > 1)
        // The fingers lift ~0.1 s in: the drawing-in still finishes, then it holds briefly.
        let early = NotchController.unfoldDelay(sinceGatherStarted: 0.1)
        #expect(abs(early - (NotchController.gatherDuration - 0.1 + NotchController.holdAfterLift)) < 0.0001)
        #expect(NotchController.unfoldDelay(sinceGatherStarted: 1) == NotchController.holdAfterLift)
    }

    @Test func shrinkingIsTellingNarrowerOrLower() {
        let wide = CGRect(x: 0, y: 0, width: 760, height: 420)
        #expect(NotchController.shrank(from: wide, to: CGRect(x: 100, y: 0, width: 560, height: 420)))
        #expect(NotchController.shrank(from: wide, to: CGRect(x: 0, y: 100, width: 760, height: 320)))
        #expect(!NotchController.shrank(from: wide, to: wide))
        #expect(!NotchController.shrank(from: wide, to: CGRect(x: 0, y: 0, width: 800, height: 500)))
    }
}
