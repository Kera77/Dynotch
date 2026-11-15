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
    private let openSettings: () -> Void
    private let model: NotchViewModel
    private let panel: NotchPanel

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var sizeObserver: AnyCancellable?
    private var hoverTimer: Timer?
    private var closeTask: Task<Void, Never>?
    private var graceUntil: Date?
    private var swipe = SwipeDetector()
    private var isMenuOpen = false

    init(screen: NSScreen, settings: AppSettings, calendar: CalendarService, openSettings: @escaping () -> Void) {
        self.settings = settings
        self.calendar = calendar
        self.openSettings = openSettings
        let geometry = Self.geometry(for: screen)
        model = NotchViewModel(settings: settings, geometry: geometry, screenName: screen.localizedName)
        // The window always has the large size, so switching views never resizes it; outside
        // the visible panel it ignores the mouse (see evaluatePointerWhileExpanded).
        let windowRect = geometry.rect(for: geometry.largeSize)
        panel = NotchPanel(contentRect: windowRect)

        let hosting = FirstMouseHostingView(rootView: NotchView(model: model, settings: settings, calendar: calendar))
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: windowRect.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    func start() {
        panel.setFrame(model.geometry.rect(for: model.geometry.largeSize), display: true)
        panel.orderFrontRegardless()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .scrollWheel, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            let consumed = MainActor.assumeIsolated { self.handleLocal(event) }
            return consumed ? nil : event
        }
        sizeObserver = model.$isLarge.dropFirst().removeDuplicates().sink { [weak self] large in
            MainActor.assumeIsolated { self?.sizeChanged(large: large) }
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        sizeObserver = nil
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

    private var keepOpenZone: CGRect {
        model.geometry.keepOpenZone(for: model.openSize)
    }

    private func pointerMoved() {
        if model.isExpanded {
            evaluatePointerWhileExpanded()
        } else if model.geometry.hoverZone.contains(NSEvent.mouseLocation) {
            expand()
        }
    }

    private func evaluatePointerWhileExpanded() {
        guard model.isExpanded, !isMenuOpen else { return }
        let isInside = keepOpenZone.contains(NSEvent.mouseLocation)
        // The window is larger than the visible panel: let clicks around the panel through.
        panel.ignoresMouseEvents = !isInside
        if isInside {
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
        withAnimation(Self.animation) { model.setExpanded(true) }
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
            if !self.isMenuOpen, !self.keepOpenZone.contains(NSEvent.mouseLocation) {
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
        case .rightMouseDown:
            showContextMenu(for: event)
            return true
        default:
            pointerMoved()
            return false
        }
    }

    // MARK: - Swipe (spec S-1…S-4)

    private func handleScroll(_ event: NSEvent) -> Bool {
        guard model.isExpanded else { return false }
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

    // MARK: - Context menu (spec C-1)

    private func showContextMenu(for event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem(title: "Beállítások…", keyEquivalent: ",") { [weak self] in
            self?.collapse()
            self?.openSettings()
        })
        menu.addItem(ClosureMenuItem(title: "Névjegy") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Kilépés", keyEquivalent: "q") {
            NSApp.terminate(nil)
        })

        isMenuOpen = true
        cancelClose()
        menu.popUp(positioning: nil, at: event.locationInWindow, in: panel.contentView)
        isMenuOpen = false
        evaluatePointerWhileExpanded()
    }
}
