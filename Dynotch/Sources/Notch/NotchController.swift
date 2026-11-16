import AppKit
import Combine
import SwiftUI

/// Owns the notch panel of one display and turns pointer/trackpad input into panel state.
@MainActor
final class NotchController {
    static let animation = Animation.spring(response: 0.38, dampingFraction: 0.82)
    /// After the panel shrinks from the large size, the pointer may be outside the smaller
    /// panel; keep it open this long so it doesn't close under the user's hand.
    private static let shrinkGracePeriod: TimeInterval = 2.5

    private let settings: AppSettings
    private let calendar: CalendarService
    private let notifications: NotificationService
    private let openSettings: () -> Void
    private let model: NotchViewModel
    private let panel: NotchPanel

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var sizeObserver: AnyCancellable?
    private var settingsObserver: AnyCancellable?
    private var hoverTimer: Timer?
    private var closeTask: Task<Void, Never>?
    private var graceUntil: Date?
    private var swipe = SwipeDetector()
    private var wasExpanded = false

    init(screen: NSScreen, services: AppServices, openSettings: @escaping () -> Void) {
        settings = services.settings
        calendar = services.calendar
        notifications = services.notifications
        self.openSettings = openSettings
        let geometry = Self.geometry(for: screen)
        model = NotchViewModel(settings: settings, geometry: geometry, screenName: screen.localizedName)
        // The window always has the large size, so switching views never resizes it; outside
        // the visible panel it ignores the mouse (see evaluatePointerWhileExpanded).
        let windowRect = geometry.rect(for: geometry.windowSize)
        panel = NotchPanel(contentRect: windowRect)

        let rootView = NotchView(
            model: model, settings: settings, calendar: calendar,
            notifications: notifications, calculator: services.calculator, notes: services.notes
        ) { [weak self] in
            self?.settingsButtonPressed()
        }
        let hosting = FirstMouseHostingView(rootView: rootView)
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: windowRect.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    func start() {
        panel.setFrame(model.geometry.rect(for: model.geometry.windowSize), display: true)
        panel.orderFrontRegardless()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .scrollWheel]) { [weak self] event in
            guard let self else { return event }
            let consumed = MainActor.assumeIsolated { self.handleLocal(event) }
            return consumed ? nil : event
        }
        sizeObserver = model.$isLarge.dropFirst().removeDuplicates().sink { [weak self] large in
            MainActor.assumeIsolated { self?.sizeChanged(large: large) }
        }
        // Fires before the change; look at the new state on the next run loop turn.
        settingsObserver = model.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.updateKeyboardFocus() }
            }
        }
    }

    // MARK: - Settings (spec C-1…C-3)

    private func settingsButtonPressed() {
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
    private func updateKeyboardFocus() {
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

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        sizeObserver = nil
        settingsObserver = nil
        closeTask?.cancel()
        stopHoverTimer()
        panel.orderOut(nil)
        panel.close()
    }

    // MARK: - Layout

    private static func geometry(for screen: NSScreen) -> NotchGeometry {
        NotchGeometry.make(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxiliaryRightWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY
        )
    }

    /// When the open panel shrinks, the pointer may end up outside it; don't close right away.
    private func sizeChanged(large: Bool) {
        graceUntil = !large && model.isExpanded ? Date().addingTimeInterval(Self.shrinkGracePeriod) : nil
    }

    // MARK: - Hover (spec N-2…N-4)

    /// Area that opens the panel: the notch, or the whole peek while a notification shows.
    private var hoverZone: CGRect {
        let geometry = model.geometry
        return notifications.peek == nil ? geometry.hoverZone : geometry.keepOpenZone(for: geometry.peekSize)
    }

    private var keepOpenZone: CGRect {
        model.geometry.keepOpenZone(for: model.openSize)
    }

    private func pointerMoved() {
        if model.isExpanded {
            evaluatePointerWhileExpanded()
        } else if hoverZone.contains(NSEvent.mouseLocation) {
            setHoveredIndicator(nil)
            expand()
        } else {
            updateHoveredIndicator()
        }
    }

    /// Which countdown beside the closed notch is under the pointer (spec K-8d). The panel
    /// ignores the mouse while closed, so this is computed from the pointer position.
    private func updateHoveredIndicator() {
        let count = calendar.indicatorEvents.count
        guard count > 0, notifications.peek == nil else {
            setHoveredIndicator(nil)
            return
        }
        let geometry = model.geometry
        let layout = IndicatorLayout(count: count)
        let point = NSEvent.mouseLocation
        if let slot = layout.slot(at: point, notchRect: geometry.notchRect) {
            setHoveredIndicator(slot)
        } else if model.hoveredIndicator != nil,
                  geometry.keepOpenZone(for: layout.size(notch: geometry.notchSize, showsLabel: true)).contains(point) {
            // Moving down onto the name keeps it visible.
            return
        } else {
            setHoveredIndicator(nil)
        }
    }

    private func setHoveredIndicator(_ index: Int?) {
        guard model.hoveredIndicator != index else { return }
        withAnimation(Self.animation) { model.hoveredIndicator = index }
    }

    private func evaluatePointerWhileExpanded() {
        guard model.isExpanded else { return }
        // While a mouse button is down (e.g. dragging a slider) the panel stays open.
        let isInside = keepOpenZone.contains(NSEvent.mouseLocation) || NSEvent.pressedMouseButtons != 0
        // The window is larger than the visible panel: let clicks around the panel through.
        panel.ignoresMouseEvents = !isInside
        if isInside || model.isPinned {
            graceUntil = nil
            cancelClose()
        } else if let graceUntil, graceUntil > Date() {
            cancelClose()
        } else {
            scheduleClose()
        }
    }

    private func expand() {
        cancelClose()
        graceUntil = nil
        panel.ignoresMouseEvents = false
        calendar.panelDidOpen()
        // Opened from a notification peek: show just that notification (spec E-4).
        let peeked = notifications.peek
        withAnimation(Self.animation) { model.setExpanded(true, presenting: peeked) }
        notifications.clearPeek()
        startHoverTimer()
    }

    private func collapse() {
        cancelClose()
        stopHoverTimer()
        graceUntil = nil
        panel.ignoresMouseEvents = true
        withAnimation(Self.animation) { model.setExpanded(false) }
    }

    private func scheduleClose() {
        guard closeTask == nil else { return }
        let delay = settings.closeDelay
        closeTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled, let self else { return }
            self.closeTask = nil
            let isOutside = !self.keepOpenZone.contains(NSEvent.mouseLocation) && NSEvent.pressedMouseButtons == 0
            if isOutside, !self.model.isPinned {
                self.collapse()
            }
        }
    }

    private func cancelClose() {
        closeTask?.cancel()
        closeTask = nil
    }

    /// While open, poll the pointer: mouse-moved events aren't reliably delivered to a
    /// non-key panel, and polling only runs while the panel is open.
    private func startHoverTimer() {
        guard hoverTimer == nil else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluatePointerWhileExpanded() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func stopHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    // MARK: - Local events

    private func handleLocal(_ event: NSEvent) -> Bool {
        guard event.window === panel else {
            if event.type == .mouseMoved { pointerMoved() }
            return false
        }
        switch event.type {
        case .scrollWheel:
            return handleScroll(event)
        default:
            pointerMoved()
            return false
        }
    }

    // MARK: - Swipe (spec S-1…S-4)

    private func handleScroll(_ event: NSEvent) -> Bool {
        // The settings scroll on their own; no feature switching there.
        guard model.isExpanded, !model.isShowingSettings, model.notification == nil else { return false }
        // Over the calendar's day strip a horizontal swipe scrolls the days (spec K-4).
        if model.currentFeature == .calendar, !model.isLarge,
           model.geometry.dayStripZone.contains(NSEvent.mouseLocation) {
            return false
        }

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
        // Normalize so positive = fingers moved right, regardless of "natural scrolling".
        let fingerDeltaX = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        let isMomentum = !event.momentumPhase.isEmpty

        if let direction = swipe.handle(
            phase: phase,
            isMomentum: isMomentum,
            fingerDeltaX: fingerDeltaX,
            deltaY: event.scrollingDeltaY
        ) {
            withAnimation(Self.animation) { model.step(direction) }
        }
        return swipe.isHorizontalGesture && (phase != .none || isMomentum)
    }
}
