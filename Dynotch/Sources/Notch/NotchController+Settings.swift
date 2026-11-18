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

    /// A click in another app closes the settings, or a reply being typed, that hold the panel
    /// open (spec C-6, E-21).
    func watchClicksOutsideSettings() {
        guard settingsClickMonitor == nil else { return }
        settingsClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.stopWatchingClicksOutsideSettings()
                guard self.model.holdsForSettings || self.model.holdsForTyping, self.model.isExpanded else { return }
                self.model.holdsForSettings = false
                self.model.holdsForTyping = false
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
            giveKeyboardBack()
        } else if model.isShowingSettings || !openedJustNow || model.currentFeature == .calculator || settings.focusFollowsMouse {
            // The calculator takes typing right away, even when opened by hover (spec SZ-10);
            // with focus following the mouse, so does every module (spec F-15).
            panel.makeKey()
        }
    }

    /// resignKey() only reports; the app in front gets its key window back for real, or its
    /// window stayed half active (e.g. VS Code did not scroll) (spec F-15).
    func giveKeyboardBack() {
        guard panel.isKeyWindow else { return }
        panel.makeFirstResponder(nil)
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != getpid() {
            front.activate()
        } else {
            NSApp.deactivate()
        }
    }

    /// Focus follows the mouse onto the open notch too, when the pointer comes back (spec F-15).
    func followFocusOntoNotch() {
        guard settings.focusFollowsMouse, model.isExpanded, model.wantsKeyboard, panel.allowsKey, !panel.isKeyWindow,
              NSEvent.pressedMouseButtons == 0, keepOpenZone.contains(NSEvent.mouseLocation)
        else { return }
        panel.makeKey()
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

// MARK: - Shrinking under the pointer (spec N-20)

extension NotchController {
    /// The panel got smaller (a tab or module with a smaller size was picked) while the pointer
    /// was inside: the former area keeps counting as inside, so the panel does not close.
    func keepShrunkArea(_ before: CGRect?) {
        guard let before, model.isExpanded else { return }
        let now = keepOpenZone
        let pointer = NSEvent.mouseLocation
        guard Self.shrank(from: before, to: now), before.contains(pointer), !now.contains(pointer) else { return }
        stickyZone = stickyZone.map { $0.union(before) } ?? before
    }

    nonisolated static func shrank(from before: CGRect, to now: CGRect) -> Bool {
        now.width < before.width - 0.5 || now.height < before.height - 0.5
    }
}
