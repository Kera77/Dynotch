import AppKit
import SwiftUI

// MARK: - Incoming call (spec P-1…P-3)

extension NotchController {
    /// The call card takes the place of everything else at the notch while the phone rings.
    func callChanged() {
        let isRinging = calls.call != nil
        if isRinging, !callIsShown {
            if model.isExpanded { collapse() }
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
            callIsShown = true
            // The card takes the mouse, which hides mouse-moved events: poll the pointer.
            startHoverTimer()
        } else if !isRinging, callIsShown {
            callIsShown = false
            stopHoverTimer()
            panel.ignoresMouseEvents = true
            if panel.allowsKey {
                panel.allowsKey = false
                panel.resignKey()
            }
            return
        }
        if callIsShown { updateCallInteraction() }
    }

    /// The card's buttons take clicks; the message field takes the keyboard.
    func updateCallInteraction() {
        let geometry = model.geometry
        let area = geometry.keepOpenZone(for: geometry.callSize(composing: calls.isComposing))
        panel.ignoresMouseEvents = !area.contains(NSEvent.mouseLocation)
        let wantsKeyboard = calls.isComposing
        guard panel.allowsKey != wantsKeyboard else { return }
        panel.allowsKey = wantsKeyboard
        if wantsKeyboard {
            panel.makeKey()
        } else {
            panel.resignKey()
        }
    }
}
