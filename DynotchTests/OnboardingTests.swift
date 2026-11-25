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

    /// End tour stops the tips; Replay brings them back (spec OB-32).
    @Test func endTourTurnsTipsOff() {
        let progress = makeProgress()
        #expect(progress.canEnd(running: false))
        progress.end()
        #expect(progress.isCompleted)
        #expect(progress.takeTip(for: .calendar) == nil)
        #expect(!progress.canEnd(running: false))
        #expect(progress.canEnd(running: true))
        progress.reset()
        progress.complete()
        #expect(progress.takeTip(for: .calendar)?.id == "calendar")
    }

    /// Every module on the modules step has its two or three sentences (spec OB-33).
    @Test func everyListedModuleHasADescription() {
        for feature in OnboardingModulesStep.groups.flatMap(\.1) {
            #expect(!OnboardingModuleTexts.text(for: feature).isEmpty)
        }
    }
}

struct WhatsNewTests {
    /// The running version has its lines, and versions run newest first (spec WN-4).
    @Test func currentVersionHasAnEntry() {
        let entry = WhatsNew.releases.first { $0.version == AppInfo.version }
        #expect(entry?.items.isEmpty == false)
        let versions = WhatsNew.releases.map(\.version)
        for (newer, older) in zip(versions, versions.dropFirst()) {
            #expect(UpdateLogic.isNewer(newer, than: older))
        }
    }

    /// A first install gets the tour; an update gets what came since (spec WN-1…WN-3).
    @Test func dueReleases() {
        #expect(WhatsNew.due(last: nil, current: "1.1.0", tourDone: false).isEmpty)
        #expect(WhatsNew.due(last: nil, current: "1.1.0", tourDone: true).map(\.version) == ["1.1.0"])
        #expect(WhatsNew.due(last: "1.1.0", current: "1.1.0", tourDone: true).isEmpty)
        #expect(WhatsNew.due(last: "0.113.0", current: "1.1.0", tourDone: true).map(\.version) == ["1.1.0", "1.0.0"])
        #expect(WhatsNew.due(last: "1.0.0", current: "1.0.5", tourDone: true).isEmpty)
    }

    /// The notch's What's new: nothing when seen or on a first install, a fixes line without an entry (spec WN-6, WN-8).
    @Test func cardAfterUpdate() {
        #expect(WhatsNew.card(last: "1.1.0", current: "1.1.0", tourDone: true) == nil)
        #expect(WhatsNew.card(last: nil, current: "1.1.0", tourDone: false) == nil)
        #expect(WhatsNew.card(last: "1.0.0", current: "1.0.5", tourDone: true)?.first?.items == [WhatsNew.fixes])
        #expect(WhatsNew.card(last: "1.0.0", current: "1.1.0", tourDone: true)?.map(\.version) == ["1.1.0"])
    }

    /// Only Got it removes the notice; another notice in its place gives it back (spec WN-7).
    @MainActor @Test func noticeStaysUntilGotIt() {
        let notices = NoticeService()
        let whatsNew = StickyNotice(title: "Updated", detail: "", date: Date(), whatsNew: WhatsNew.releases)
        notices.show(whatsNew)
        notices.dismiss()
        #expect(notices.notice == whatsNew)
        notices.show(StickyNotice(title: "Claude finished", detail: "", date: Date()))
        notices.dismiss()
        #expect(notices.notice == whatsNew)
        notices.dismissWhatsNew()
        #expect(notices.notice == nil)
    }
}
