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
    /// How long everything is drawn into the notch before it unfolds.
    static let gatherDuration: TimeInterval = 0.16
    /// The unfolding: a soft spring with a hint of overshoot.
    static let unfoldAnimation = Animation.spring(response: 0.62, dampingFraction: 0.74)

    /// After a Space switch on this display, whatever stands beside the closed notch is drawn in
    /// and unfolds again, as if the notch had come along with the new Space.
    func spaceDidChange() {
        let screen = model.geometry.screenFrame
        guard screen.contains(NSEvent.mouseLocation), !model.isExpanded, !callIsShown,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else { return }
        withAnimation(.easeIn(duration: Self.gatherDuration)) { model.setGathered(true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.gatherDuration + 0.02) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                withAnimation(Self.unfoldAnimation) { self.model.setGathered(false) }
            }
        }
    }
}
