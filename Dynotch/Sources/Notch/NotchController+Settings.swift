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
            withAnimation(Self.animation) { model.setShowingSettings(!model.isShowingSettings) }
        }
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
        } else if model.isShowingSettings || !openedJustNow {
            panel.makeKey()
        }
    }
}

// MARK: - Space switch (spec N-10)

extension NotchController {
    /// Drawing in, as the swipe starts.
    static let gatherAnimation = Animation.easeOut(duration: 0.18)
    /// Unfolding as the fingers lift: over before the Spaces stop sliding.
    static let unfoldAnimation = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// If the end of the swipe is missed, the notch unfolds by itself after this long.
    static let gatherTimeout: TimeInterval = 2.5

    /// The Space-switching swipe started: whatever stands beside the closed notch is drawn in.
    func spaceSwipeBegan() {
        guard !model.isExpanded, !callIsShown, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        withAnimation(Self.gatherAnimation) { model.setGathered(true) }
        gatherTask?.cancel()
        gatherTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.gatherTimeout))
            guard !Task.isCancelled else { return }
            self?.spaceSwipeEnded()
        }
    }

    /// The fingers lifted (or the Space changed): it unfolds again.
    func spaceSwipeEnded() {
        gatherTask?.cancel()
        gatherTask = nil
        guard model.isGathered else { return }
        withAnimation(Self.unfoldAnimation) { model.setGathered(false) }
    }
}
