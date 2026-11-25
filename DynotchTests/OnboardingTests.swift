@testable import Dynotch
import Foundation
import Testing

struct OnboardingTests {
    private func makeProgress() -> OnboardingProgress {
        let name = "OnboardingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return OnboardingProgress(defaults: defaults)
    }

    @Test func stepsRunInOrder() {
        #expect(OnboardingStep.welcome.previous == nil)
        #expect(OnboardingStep.welcome.next == .openClose)
        #expect(OnboardingStep.ready.isLast)
        #expect(OnboardingStep.allCases.count == 9)
        #expect(OnboardingStep.allCases.filter(\.isPractice) == [.openClose, .moving])
    }

    @Test func firstLaunchThenDone() {
        let progress = makeProgress()
        #expect(!progress.isCompleted)
        #expect(progress.savedStep == .welcome)
        progress.save(.look)
        #expect(progress.savedStep == .look)
        progress.complete()
        #expect(progress.isCompleted)
        #expect(progress.savedStep == .welcome)
    }

    @Test func replayResetsTourAndTips() {
        let progress = makeProgress()
        progress.complete()
        _ = progress.takeTip(for: .calendar)
        progress.reset()
        #expect(!progress.isCompleted)
        #expect(progress.seenTips.isEmpty)
    }

    @Test func tipsOnlyAfterTheTourAndOnce() {
        let progress = makeProgress()
        #expect(progress.takeTip(for: .calendar) == nil)
        progress.complete()
        #expect(progress.takeTip(for: .calendar)?.id == "calendar")
        #expect(progress.takeTip(for: .calendar) == nil)
        #expect(progress.takeTip(for: .tray)?.id == "tray")
        // The second module seen: the resize tip comes once, on the next open.
        #expect(progress.takeTip(for: .tray)?.id == OnboardingTips.resizeID)
        #expect(progress.takeTip(for: .tray) == nil)
    }

    /// Every module has a first-use tip and a line on the modules step (spec OB-29).
    @Test func everyModuleHasATip() {
        for feature in FeatureID.allCases {
            #expect(!OnboardingTips.text(for: feature).isEmpty)
        }
    }
}
