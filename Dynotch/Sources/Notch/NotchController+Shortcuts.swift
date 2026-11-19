import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: - Shortcuts (spec SC-1, SC-2)

extension NotchController {
    /// Opens the feature, or closes the panel if it already shows it.
    func toggle(_ feature: FeatureID, pinned: Bool) {
        guard settings.isEnabled(feature), !callIsShown else { return }
        let showsIt = model.isExpanded && model.currentFeature == feature && !model.isPreview
            && !model.isShowingSettings && !model.isShowingNotifications
        if showsIt {
            // Already open by hover: the shortcut pins it instead of closing it (spec SC-2).
            if pinned, !model.isPinned {
                model.isPinned = true
            } else {
                collapse()
            }
            return
        }
        if model.isExpanded, model.isShowingNotifications { collapse() }
        if !model.isExpanded {
            notifications.clearPeek()
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
            expand()
        }
        openFully()
        withAnimation(Self.animation) { model.select(feature, remember: false, exact: true) }
        if pinned {
            model.isPinned = true
        } else {
            // The pointer is elsewhere: don't close before it has been on the panel.
            isHeldOpen = true
        }
        if model.wantsKeyboard {
            panel.allowsKey = true
            panel.makeKey()
        }
    }
}

extension NotchController {
    /// Pins the open panel or releases it; a closed panel opens pinned (spec SC-3).
    func togglePin() {
        guard !callIsShown else { return }
        if model.isExpanded {
            model.isPinned.toggle()
            // Released with the pointer elsewhere: close as usual.
            if !model.isPinned { isHeldOpen = false }
            return
        }
        notifications.clearPeek()
        setHoveredIndicator(nil)
        setHoveredBadge(nil)
        expand()
        model.isPinned = true
        isHeldOpen = false
    }
}

// MARK: - Sticky notice (spec CN-1)

extension NotchController {
    /// Where the notice is written: under the indicators, or under the bare notch.
    func noticeArea(for layout: IndicatorLayout) -> CGRect {
        let geometry = model.geometry
        let rect = layout.isEmpty
            ? geometry.rect(for: CGSize(width: IndicatorLayout.labelWidth, height: geometry.notchSize.height + IndicatorLayout.labelHeight))
            : layout.rect(notchRect: geometry.notchRect, labelHeight: IndicatorLayout.labelHeight)
        return rect.insetBy(dx: -4, dy: -NotchGeometry.topEdgeTolerance)
    }

    /// True when this scroll event completes a two-finger swipe up.
    func isSwipeUp(_ event: NSEvent) -> Bool {
        let phase: SwipeDetector.Phase
        if event.phase.contains(.began) {
            phase = .began
        } else if event.phase.contains(.changed) {
            phase = .changed
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            phase = .ended
        } else {
            phase = .none
        }
        // Positive = fingers moved up, regardless of "natural scrolling".
        let fingerUp = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
        return announcementSwipe.handle(phase: phase, fingerUp: fingerUp, deltaX: event.scrollingDeltaX)
    }
}

// MARK: - Claude chat (spec CC-3, CC-5)

extension NotchController {
    func chatChanged() {
        withAnimation(Self.animation) { model.setChatTall(chat.isTall) }
    }

    /// The panel was opened while "Claude answered" hangs under the notch: show the answer.
    func showAnswerIfReady() {
        guard notices.notice?.opensChat == true, settings.isEnabled(.claudeChat) else { return }
        notices.dismiss()
        withAnimation(Self.animation) { model.select(.claudeChat, exact: true) }
    }

    /// Hovering a question of Claude Code brings the app it runs in forward, once (spec CQ-3).
    func bringsAskerForward(at point: CGPoint, layout: IndicatorLayout) -> Bool {
        guard let notice = notices.notice, notice.isQuestion, let app = notice.appIdentifier,
              model.hoveredIndicator == nil, calendar.announcement == nil, noticeArea(for: layout).contains(point)
        else { return false }
        guard activatedQuestion != notice.date else { return true }
        activatedQuestion = notice.date
        NSRunningApplication.runningApplications(withBundleIdentifier: app).first?.activate()
        return true
    }

    /// A click on a "finished" notice brings forward the app the work ran in, with the project's
    /// window, and the notice goes; a question stays until it is answered (spec CN-6, CN-7).
    func openNoticeApp() {
        guard let notice = notices.notice else { return }
        if notice.opensChat {
            showAnswerIfReady()
            return
        }
        if let app = notice.appIdentifier { NoticeApp.bringForward(app, project: notice.detail) }
        guard !notice.isQuestion else { return }
        withAnimation(NotchView.quickAnimation) { notices.dismiss() }
    }

    /// Hovering the "Claude answered" line opens the chat.
    func opensAnswer(at point: CGPoint, layout: IndicatorLayout) -> Bool {
        guard notices.notice?.opensChat == true, model.hoveredIndicator == nil, calendar.announcement == nil,
              settings.isEnabled(.claudeChat), noticeArea(for: layout).contains(point)
        else { return false }
        setHoveredBadge(nil)
        expand()
        return true
    }
}

// MARK: - Preview on hover (spec PV-1…PV-3)

extension NotchController {
    /// The panel shows the preview; only a click or a swipe down opens it fully (spec PV-5).
    func startPreview() {
        model.stripOrigin = NSEvent.mouseLocation.x - model.geometry.notchRect.midX
        model.setPreview(true)
    }

    func openFully() {
        guard model.isPreview else { return }
        withAnimation(Self.animation) { model.setPreview(false) }
    }

    /// The module strip under the preview (spec PV-6); not while files are dropped on the wings.
    var showsPreviewStrip: Bool {
        model.isPreview && !model.isShowingDropZone && settings.moduleStrip
            && ModuleStripChoice.features(from: settings.listedFeatures).count > 1
    }
}

// MARK: - Keyboard in the notch (spec N-15)

extension NotchController {
    /// Esc closes, ⌘1–9 picks a module, ← → step through them (not while typing in a field).
    func handleKey(_ event: NSEvent) -> Bool {
        // The screenshot editor handles its own keys (spec SH-7).
        guard model.isExpanded, model.editor == nil else { return false }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let isTyping = panel.firstResponder is NSText
        switch Int(event.keyCode) {
        case kVK_Escape where !model.isShowingOverlayPage:
            collapse()
            return true
        case kVK_LeftArrow where flags.isEmpty && !isTyping && !model.isShowingSettings:
            withAnimation(Self.animation) { model.step(.previous) }
            return true
        case kVK_RightArrow where flags.isEmpty && !isTyping && !model.isShowingSettings:
            withAnimation(Self.animation) { model.step(.next) }
            return true
        default:
            guard flags == .command, let digit = Int(event.charactersIgnoringModifiers ?? ""), (1...9).contains(digit) else { return false }
            let features = settings.listedFeatures
            guard features.indices.contains(digit - 1) else { return false }
            withAnimation(Self.animation) { model.select(features[digit - 1]) }
            return true
        }
    }
}
