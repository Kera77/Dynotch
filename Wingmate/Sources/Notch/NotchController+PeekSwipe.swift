import AppKit
import SwiftUI

// MARK: - Notifications under the notch open with a swipe down (spec DS-4)

extension NotchController {
    /// With swipe drop-downs on, the small notifications under the closed notch (a new
    /// notification, a Beeper message, a screenshot just made) wait for a swipe instead of hover.
    var peeksWaitForSwipe: Bool {
        GestureSettings.shared.dropdownsOnSwipe && !settings.noticesBeside
    }

    /// The pointer is on the screenshot just made (its pop-up under the notch).
    var isOverScreenshotPeek: Bool {
        guard let shot = screenshots.peek, !shot.isVideo else { return false }
        return model.geometry.keepOpenZone(for: model.geometry.peekSize).contains(NSEvent.mouseLocation)
    }

    /// The pointer is on the notification under the notch (or the notch above it).
    var isOverNotificationPeek: Bool {
        guard notifications.peek != nil else { return false }
        let zone = model.geometry.keepOpenZone(for: notifications.peekSize(in: model.geometry))
        return zone.contains(NSEvent.mouseLocation)
    }

    /// A swipe down over the notification opens its card, over the screenshot the editor.
    /// - Returns: true when the event was used.
    func handlePeekSwipe(_ event: NSEvent) -> Bool {
        guard peeksWaitForSwipe, !model.isExpanded, !callIsShown else { return false }
        let overShot = isOverScreenshotPeek
        guard overShot || isOverNotificationPeek else { return false }
        let began: Bool? = event.phase.isEmpty && event.momentumPhase.isEmpty ? nil : event.phase.contains(.began)
        // Positive = fingers moved down, regardless of "natural scrolling".
        let fingerDown = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        let direction = model.reveal.swipe.handle(
            fingerDown: fingerDown, across: event.scrollingDeltaX, began: began,
            isMomentum: !event.momentumPhase.isEmpty, time: event.timestamp
        )
        guard direction == .open else { return direction != nil ? false : true }
        Haptics.perform(.open, settings: settings)
        if overShot, let shot = screenshots.peek {
            openScreenshotEditor(shot.url, fromPeek: true)
        } else {
            hideStrip()
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
            expand()
        }
        return true
    }
}
