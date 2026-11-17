import AppKit
import SwiftUI

extension NotchController {
    // MARK: - Settings (spec C-1…C-3)

    func settingsButtonPressed() {
        switch settings.settingsPresentation {
        case .window:
            collapse()
            openSettings()
        case .notch:
            let showing = !model.isShowingSettings
            withAnimation(Self.animation) { model.setShowingSettings(showing) }
            // The settings stay open while you work in them, until a click outside (spec C-6).
            model.holdsForSettings = showing
            if showing { watchClicksOutsideSettings() }
        }
    }

    /// A click in another app closes the settings that hold the panel open (spec C-6).
    func watchClicksOutsideSettings() {
        guard settingsClickMonitor == nil else { return }
        settingsClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.stopWatchingClicksOutsideSettings()
                guard self.model.holdsForSettings, self.model.isExpanded else { return }
                self.model.holdsForSettings = false
                if !self.model.isPinned { self.collapse() }
            }
        }
    }

    func stopWatchingClicksOutsideSettings() {
        if let settingsClickMonitor { NSEvent.removeMonitor(settingsClickMonitor) }
        settingsClickMonitor = nil
    }

    /// The panel takes keyboard focus only for the settings and the calculator. Opening by
    /// hover never steals focus from the app being used: then a click into the panel does it.
    func updateKeyboardFocus() {
        guard !callIsShown else { return }
        let wantsKeyboard = model.wantsKeyboard
        let openedJustNow = model.isExpanded && !wasExpanded
        wasExpanded = model.isExpanded
        guard wantsKeyboard != panel.allowsKey else { return }
        panel.allowsKey = wantsKeyboard
        if !wantsKeyboard {
            panel.resignKey()
        } else if model.isShowingSettings || !openedJustNow || model.currentFeature == .calculator {
            // The calculator takes typing right away, even when opened by hover (spec SZ-10).
            panel.makeKey()
        }
    }
}

// MARK: - Space switch (spec N-10)

extension NotchController {
    /// Drawing in, as the swipe starts.
    static let gatherDuration: TimeInterval = 0.16
    static let gatherAnimation = Animation.easeOut(duration: gatherDuration)
    /// The fingers lift about 0.1 s into the swipe, the Spaces slide on for about 0.4 s more:
    /// the notch stays drawn in this long, then unfolds and has settled when they stop.
    static let holdAfterLift: TimeInterval = 0.12
    static let unfoldAnimation = Animation.spring(response: 0.3, dampingFraction: 0.84)
    /// If the end of the swipe is missed, the notch unfolds by itself after this long.
    static let gatherTimeout: TimeInterval = 2.5

    /// When to unfold after the fingers lifted, counted from now: the drawing-in always
    /// finishes, then the notch holds a moment while the Spaces slide.
    static func unfoldDelay(sinceGatherStarted elapsed: TimeInterval) -> TimeInterval {
        max(gatherDuration - elapsed, 0) + holdAfterLift
    }

    /// The Space-switching swipe started: whatever stands beside the closed notch is drawn in.
    func spaceSwipeBegan() {
        guard !model.isExpanded, !callIsShown, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        gatherStarted = Date()
        withAnimation(Self.gatherAnimation) { model.setGathered(true) }
        scheduleUnfold(after: Self.gatherTimeout)
    }

    /// The fingers lifted: unfold so that it is over when the Spaces stop sliding.
    func spaceSwipeLifted() {
        guard model.isGathered else { return }
        let elapsed = gatherStarted.map { Date().timeIntervalSince($0) } ?? Self.gatherDuration
        scheduleUnfold(after: Self.unfoldDelay(sinceGatherStarted: elapsed))
    }

    /// Unfolds now (the Space changed, or the swipe's end was missed).
    func spaceSwipeEnded() {
        gatherTask?.cancel()
        gatherTask = nil
        gatherStarted = nil
        guard model.isGathered else { return }
        withAnimation(Self.unfoldAnimation) { model.setGathered(false) }
    }

    private func scheduleUnfold(after delay: TimeInterval) {
        gatherTask?.cancel()
        gatherTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.spaceSwipeEnded()
        }
    }
}
