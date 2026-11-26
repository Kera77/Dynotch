import Foundation

extension NoticeService {
    /// "Test 1.x.y" once per test build, after What's new (spec TL-4).
    func announceTestPlan() {
        guard notice?.whatsNew == nil, second?.whatsNew == nil, let items = TestPlan.current,
              TestPlanStore.shouldAnnounce(AppInfo.version)
        else { return }
        show(StickyNotice(
            title: "Test \(AppInfo.version)", detail: "\(items.count) things to check", date: Date(),
            symbol: "checklist", opensTestList: true
        ))
    }

    /// After What's new's Got it, or by itself when there is no What's new this launch (spec TL-4).
    func wireTestPlan(openTesting: @escaping @MainActor () -> Void) {
        self.openTesting = openTesting
        onWhatsNewDismissed = { [weak self] in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                self?.announceTestPlan()
            }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !OnboardingController.isRunning else { return }
            self?.announceTestPlan()
        }
    }
}
