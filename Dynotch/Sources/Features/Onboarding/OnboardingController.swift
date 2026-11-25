import AppKit
import ServiceManagement
import SwiftUI

/// What the tour view shows; the controller moves it along (spec OB-9).
@MainActor
@Observable
final class OnboardingModel {
    var step = OnboardingStep.welcome
    /// The practice step's move has been done (spec OB-15, OB-16).
    var practiceDone = false
    /// Open and close: the notch has opened, now it should close.
    var practiceOpened = false
    /// Skipped: one line says where to replay it, then it closes (spec OB-3).
    var showsSkipNote = false
}

/// Runs the first-launch tour in a panel at the notch (spec OB-1…OB-25).
@MainActor
final class OnboardingController {
    /// While the tour runs, nothing pops up by itself (spec OB-11).
    private(set) static var isRunning = false
    /// The real notch stays closed under the tour, except while practising (spec OB-10).
    static var blocksNotch: Bool { isRunning && shared?.model.step.isPractice != true }
    private(set) static var shared: OnboardingController?

    let settings: AppSettings
    let switcher: SwitcherSettings?
    let model = OnboardingModel()
    private let progress: OnboardingProgress
    private let notchModels: () -> [NotchViewModel]
    private let collapseNotches: () -> Void
    private let closeSettings: () -> Void
    private var panel: CardPanel?
    private var timer: Timer?
    private var keyMonitor: Any?
    private var featureAtOpen: FeatureID?

    init(
        settings: AppSettings, switcher: SwitcherSettings?,
        notchModels: @escaping () -> [NotchViewModel],
        collapseNotches: @escaping () -> Void, closeSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.switcher = switcher
        self.progress = OnboardingProgress(defaults: settings.defaults)
        self.notchModels = notchModels
        self.collapseNotches = collapseNotches
        self.closeSettings = closeSettings
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

    /// The card takes its content's size (spec OB-30).
    func fit(_ size: CGSize) {
        panel?.fit(size)
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
        let panel = CardPanel(rootView: OnboardingView(controller: self, model: model))
        panel.anchor = { [weak self] in self?.notchBottom() }
        self.panel = panel
        watchKeys()
        go(to: step)
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
        guard !model.showsSkipNote else { return }
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
        model.practiceDone = false
        model.practiceOpened = false
        featureAtOpen = nil
        if !step.isPractice { collapseNotches() }
        withAnimation(Motion.spring) { model.step = step }
        progress.save(step)
        DiagnosticsLog.append("onboarding", "step \(step)")
        panel?.follow()
        if step.isPractice { startWatchingNotch() } else { stopWatchingNotch() }
    }

    private func close() {
        stopWatchingNotch()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel?.dismiss()
        panel = nil
        model.showsSkipNote = false
        Self.isRunning = false
    }

    // MARK: - Practice on the real notch (spec OB-15, OB-16, OB-24)

    private func startWatchingNotch() {
        guard timer == nil else { return }
        timer = RepeatingTimer.start(every: 0.15) { [weak self] in self?.watchNotch() }
    }

    private func stopWatchingNotch() {
        timer?.invalidate()
        timer = nil
    }

    private func watchNotch() {
        panel?.follow()
        guard !model.practiceDone else { return }
        let open = notchModels().first { $0.isExpanded }
        switch model.step {
        case .openClose:
            if open != nil, !model.practiceOpened {
                withAnimation(Motion.spring) { model.practiceOpened = true }
            } else if open == nil, model.practiceOpened {
                practiceSucceeded()
            }
        case .moving:
            guard let open else { return }
            guard let first = featureAtOpen else {
                featureAtOpen = open.currentFeature
                return
            }
            if open.currentFeature != first { practiceSucceeded() }
        default:
            break
        }
    }

    /// The card's top centre: under the closed notch, or under the open panel and the module
    /// strip below the Wings (spec OB-34, OB-35).
    private func notchBottom() -> CGPoint? {
        guard let screen = CardPanel.screen else { return nil }
        let models = notchModels()
        guard let notch = models.first(where: { $0.geometry.screenFrame == screen.frame }) ?? models.first else { return nil }
        let geometry = notch.geometry
        var height = geometry.notchSize.height
        if notch.isExpanded {
            height = max(notch.openSize.height, height)
            if notch.isPreview { height += NotchGeometry.stripGap + NotchGeometry.stripIconSize + 4 }
        }
        return CGPoint(x: geometry.notchRect.midX, y: geometry.screenFrame.maxY - height - CardPanel.gap)
    }

    private func practiceSucceeded() {
        withAnimation(Motion.spring) { model.practiceDone = true }
        let step = model.step
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, Self.isRunning, self.model.step == step else { return }
                self.next()
            }
        }
    }

    // MARK: - Keys (spec OB-9)

    private func watchKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let handled = MainActor.assumeIsolated { self.handleKey(event) }
            return handled ? nil : event
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard event.window === panel else { return false }
        switch event.keyCode {
        case 53: skip()
        case 123: back()
        case 124: next()
        default: return false
        }
        return true
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
