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
    private var panel: OnboardingPanel?
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
        let panel = OnboardingPanel(controller: self)
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
        if model.step.isPractice { panel?.place(compact: false) }
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
        panel?.place(compact: step.isPractice)
        if step.isPractice { startWatchingNotch() } else { stopWatchingNotch() }
    }

    private func close() {
        stopWatchingNotch()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel?.orderOut(nil)
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

/// The tour's window: at the notch, like the open notch, or a small card lower down while
/// the real notch is practised on (spec OB-8).
final class OnboardingPanel: NSPanel {
    static let size = CGSize(width: 520, height: 440)
    static let compactSize = CGSize(width: 380, height: 150)

    init(controller: OnboardingController) {
        super.init(
            contentRect: CGRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // Above the notch panel (main menu + 3), so the tour covers the notch (spec OB-8).
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 4)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: OnboardingView(controller: controller, model: controller.model))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Allowed over the menu bar, like the notch panel.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// The display with a built-in notch, otherwise the main one (spec OB-1).
    private static var screen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// The menu bar's height on that display: the content starts under it.
    static var topInset: CGFloat {
        guard let screen else { return 32 }
        return max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY, 24)
    }

    func place(compact: Bool) {
        guard let screen = Self.screen else { return }
        let area = screen.frame
        let frame: CGRect
        if compact {
            // Lower down, so the real notch opens freely above it.
            let size = Self.compactSize
            frame = CGRect(x: area.midX - size.width / 2, y: area.midY - size.height, width: size.width, height: size.height)
        } else {
            let size = CGSize(width: Self.size.width, height: Self.size.height + Self.topInset)
            frame = CGRect(x: area.midX - size.width / 2, y: area.maxY - size.height, width: size.width, height: size.height)
        }
        setFrame(frame, display: true, animate: isVisible)
        orderFrontRegardless()
        makeKey()
    }
}
