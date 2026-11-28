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
        let direction = revealDirection(of: event)
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

extension NotchController {
    /// Feeds the scroll event to the swipe being gathered; a direction once a swipe completes.
    func revealDirection(of event: NSEvent) -> RevealSwipe.Direction? {
        let began: Bool? = event.phase.isEmpty && event.momentumPhase.isEmpty ? nil : event.phase.contains(.began)
        // Positive = fingers moved down, regardless of "natural scrolling".
        let fingerDown = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
        return model.reveal.swipe.handle(
            fingerDown: fingerDown, across: event.scrollingDeltaX, began: began,
            isMomentum: !event.momentumPhase.isEmpty, time: event.timestamp
        )
    }

    /// The notice is what is written under the notch: a swipe up puts it away (spec CN-1).
    func handleNoticeScroll(_ event: NSEvent, layout: IndicatorLayout) -> Bool {
        guard let notice = notices.notice, noticeArea(for: layout).contains(NSEvent.mouseLocation) else { return false }
        // "Claude finished" opens downwards to tell its task (spec CN-10).
        if notice.task != nil, !settings.noticesBeside { return handleNoticeTaskSwipe(event) }
        if isSwipeUp(event), notice.whatsNew == nil { // What's new stays (spec WN-7).
            foldPeekAway { notices.dismiss() }
        }
        return true
    }

    /// Over "Claude finished": a swipe down shows its task, a swipe up folds it first, then
    /// puts the notice away (spec CN-10, CN-1).
    func handleNoticeTaskSwipe(_ event: NSEvent) -> Bool {
        guard let direction = revealDirection(of: event) else { return true }
        switch direction {
        case .open:
            guard !notices.revealsTask else { return true }
            Haptics.perform(.open, settings: settings)
            withAnimation(Self.animation) { notices.revealsTask = true }
        case .close where notices.revealsTask:
            withAnimation(Self.animation) { notices.revealsTask = false }
        case .close:
            foldPeekAway { notices.dismiss() }
        }
        return true
    }
}
