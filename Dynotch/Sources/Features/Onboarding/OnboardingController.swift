import AppKit
import ServiceManagement
import SwiftUI

/// What the tour view shows; the controller moves it along (spec OB-9).
@MainActor
@Observable
final class OnboardingModel {
    var step = OnboardingStep.welcome
    /// Skipped: one line says where to replay it, then it closes (spec OB-3).
    var showsSkipNote = false
    /// The page's measured height under the notch, for the panel's size (spec OB-36).
    var contentHeight: CGFloat = 0
}

/// Runs the first-launch tour in the notch, like What's new (spec OB-1…OB-25, OB-36).
@MainActor
final class OnboardingController {
    /// While the tour runs, nothing pops up by itself (spec OB-11).
    private(set) static var isRunning = false
    /// The other notches stay closed while the tour runs (spec OB-36).
    static var blocksNotch: Bool { isRunning }
    private(set) static var shared: OnboardingController?

    let settings: AppSettings
    let switcher: SwitcherSettings?
    let model = OnboardingModel()
    private let progress: OnboardingProgress
    private let notchModels: () -> [NotchViewModel]
    private let collapseNotches: () -> Void
    private let closeSettings: () -> Void
    /// Shows or hides the tour in the notch (spec OB-36).
    private let present: (Bool) -> Void

    init(
        settings: AppSettings, switcher: SwitcherSettings?,
        notchModels: @escaping () -> [NotchViewModel],
        collapseNotches: @escaping () -> Void, closeSettings: @escaping () -> Void,
        present: @escaping (Bool) -> Void
    ) {
        self.settings = settings
        self.switcher = switcher
        self.progress = OnboardingProgress(defaults: settings.defaults)
        self.notchModels = notchModels
        self.collapseNotches = collapseNotches
        self.closeSettings = closeSettings
        self.present = present
        Self.shared = self
    }

    /// First launch, or a tour left half way (spec OB-1, OB-4); waits for a quiet screen (OB-12).
    func startIfNeeded() {
        guard !progress.isCompleted else { return }
        startWhenClear(at: progress.savedStep)
    }

    /// Settings › General › Replay tour (spec OB-5).
    func replay() {
        progress.reset()
        closeSettings()
        collapseNotches()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            MainActor.assumeIsolated { self?.start(at: .welcome) }
        }
    }

    /// The panel takes the page's height (spec OB-36).
    func fit(_ height: CGFloat) {
        guard height > 1, abs(height - model.contentHeight) > 0.5 else { return }
        model.contentHeight = height
    }

    /// Settings › General › End tour: stops the tour and the first-use tips (spec OB-32).
    func end() {
        DiagnosticsLog.append("onboarding", "ended")
        progress.end()
        if Self.isRunning { close() }
    }

    var canEnd: Bool { progress.canEnd(running: Self.isRunning) }

    private func startWhenClear(at step: OnboardingStep) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !Self.isRunning else { return }
                let busy = self.notchModels().contains {
                    $0.isScreenShared || $0.isHiddenForFullScreen || $0.isHiddenForMissionControl
                }
                if busy { self.startWhenClear(at: step) } else { self.start(at: step) }
            }
        }
    }

    private func start(at step: OnboardingStep) {
        guard !Self.isRunning else { return }
        Self.isRunning = true
        DiagnosticsLog.append("onboarding", "started at \(step)")
        go(to: step)
        present(true)
    }

    // MARK: - Moving along

    func next() {
        guard let next = model.step.next else { return finish() }
        go(to: next)
    }

    func back() {
        guard let previous = model.step.previous else { return }
        go(to: previous)
    }

    func skip() {
        guard Self.isRunning, !model.showsSkipNote else { return }
        DiagnosticsLog.append("onboarding", "skipped at \(model.step)")
        progress.complete()
        model.showsSkipNote = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    func finish() {
        DiagnosticsLog.append("onboarding", "finished")
        progress.complete()
        close()
    }

    private func go(to step: OnboardingStep) {
        withAnimation(Motion.spring) { model.step = step }
        progress.save(step)
        DiagnosticsLog.append("onboarding", "step \(step)")
    }

    private func close() {
        guard Self.isRunning else { return }
        Self.isRunning = false
        present(false)
        model.showsSkipNote = false
    }

    // MARK: - Settings shown in the tour

    var neededPermissions: [Permission] {
        var permissions: [Permission] = [.accessibility]
        if settings.isEnabled(.notifications) { permissions.append(.fullDiskAccess) }
        if settings.isEnabled(.calendar) { permissions.append(.calendar) }
        if settings.isEnabled(.reminders) { permissions.append(.reminders) }
        if settings.isEnabled(.battery) { permissions.append(.bluetooth) }
        if settings.callsEnabled { permissions.append(.contacts) }
        return permissions
    }

    static var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            DiagnosticsLog.append("onboarding", "launch at login failed: \(error.localizedDescription)")
        }
    }
}
