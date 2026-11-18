import AppKit
import Combine
import SwiftUI

/// Owns the notch panel of one display and turns pointer/trackpad input into panel state.
@MainActor
final class NotchController {
    static let animation = Motion.spring
    /// After the panel shrinks from the large size, the pointer may be outside the smaller
    /// panel; keep it open this long so it doesn't close under the user's hand.
    private static let shrinkGracePeriod: TimeInterval = 2.5

    let settings: AppSettings
    let calendar: CalendarService
    let notifications: NotificationService
    let claudeUsage: ClaudeUsageService
    let reminders: RemindersStore
    let tasks: TaskIndicator
    let calculator: CalculatorStore
    let tray: TrayStore
    let devices: DeviceWatcher
    let badges: BadgeService
    let calls: CallService
    private var callObserver: AnyCancellable?
    var callIsShown = false
    let notices: NoticeService
    let chat: ClaudeChatService
    let battery: BatteryService
    private var chatObserver: AnyCancellable?
    private var spaceObserver: NSObjectProtocol?
    var gatherTask: Task<Void, Never>?
    var gatherStarted: Date?
    /// Opened with a shortcut: stays open until the pointer has been on the panel (spec SC-1).
    var isHeldOpen = false
    /// The larger area of before a size change made by a click in the panel: still "inside"
    /// until the pointer leaves it (spec N-20).
    var stickyZone: CGRect?
    var previewTask: Task<Void, Never>?
    let openSettings: () -> Void
    let model: NotchViewModel
    let panel: NotchPanel
    /// The glass behind the panel, in a window that never takes the keyboard (spec D-6).
    let glassPanel: GlassPanel

    private var globalMonitor: Any?
    private var scrollMonitor: Any?
    var announcementSwipe = VerticalSwipe()
    private var localMonitor: Any?
    private var sizeObserver: AnyCancellable?
    private var settingsObserver: AnyCancellable?
    var beeperListObserver: AnyCancellable?
    private var hoverTimer: Timer?
    var fullScreenTimer: Timer?
    private var closeTask: Task<Void, Never>?
    private var graceUntil: Date?
    var swipe = SwipeDetector()
    var dayStepper = DayStepper()
    /// Swipes over the feature icons move them by one icon per step (spec M-9).
    var switcherStepper: DayStepper = {
        var stepper = DayStepper()
        stepper.stepWidth = FeatureSwitcher.step
        return stepper
    }()
    /// The current trackpad gesture already switched features: it must not step days too.
    var gestureSwitchedFeature = false
    /// After the announcement was swiped away the pointer is still on it: no hover details until
    /// it leaves, so only the countdown stays (spec K-8f).
    var suppressIndicatorHover = false
    var wasExpanded = false
    /// The question notice whose app was already brought forward (spec CQ-3).
    var activatedQuestion: Date?
    /// Watches for the click outside that closes the settings (spec C-6).
    var settingsClickMonitor: Any?
    /// Waits for the pointer to rest on the notch's bottom edge (spec MS-2).
    var stripTask: Task<Void, Never>?

    init(screen: NSScreen, services: AppServices, openSettings: @escaping () -> Void) {
        settings = services.settings
        calendar = services.calendar
        notifications = services.notifications
        claudeUsage = services.claudeUsage
        reminders = services.reminders
        tasks = services.tasks
        calculator = services.calculator
        tray = services.tray
        devices = services.devices
        badges = services.badges
        calls = services.calls
        notices = services.notices
        chat = services.chat
        battery = services.battery
        self.openSettings = openSettings
        let geometry = Self.geometry(for: screen)
        model = NotchViewModel(settings: settings, geometry: geometry, screenName: screen.localizedName)
        // The window always has the large size, so switching views never resizes it; outside
        // the visible panel it ignores the mouse (see evaluatePointerWhileExpanded).
        let windowRect = geometry.rect(for: geometry.windowSize)
        panel = NotchPanel(contentRect: windowRect)
        glassPanel = GlassPanel(level: panel.level)

        var rootView = NotchView(
            model: model, settings: settings, calendar: calendar,
            notifications: notifications, calculator: services.calculator, notes: services.notes,
            reminders: services.reminders, tasks: services.tasks, claudeUsage: services.claudeUsage, hud: services.hud,
            badges: services.badges,
            calls: services.calls, keyboardLock: services.keyboardLock,
            notices: services.notices, chat: services.chat, battery: services.battery, shortcuts: services.shortcuts,
            updates: services.updates, tablets: services.tablets, clipboard: services.clipboard,
            clipboardPicker: services.clipboardPicker, tray: services.tray, beeper: services.beeper, devices: services.devices
        ) { [weak self] in
            self?.settingsButtonPressed()
        }
        rootView.switcher = services.switcher
        rootView.closeNotifications = { [weak self] in self?.closeNotificationCard() }
        observeBeeperList(services.beeper)
        rootView.clearNotifications = { [weak self] in self?.clearAllNotifications() }
        rootView.openFully = { [weak self] in self?.openFully() }
        rootView.openModule = { [weak self] in self?.openFromStrip($0) }
        rootView.keepInTray = { [weak self] in self?.keepInTray($0) }
        model.requestCollapse = { [weak self] in self?.collapse() }
        rootView.sendWithAirDrop = { [weak self] in self?.sendWithAirDrop($0) }
        rootView.showBadgeNotifications = { [weak self] in self?.showNotifications(for: $0) }
        var glassView = rootView
        glassView.layer = .glass
        glassPanel.contentView = NSHostingView(rootView: glassView)
        let hosting = FirstMouseHostingView(rootView: rootView)
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: windowRect.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
    }

    // MARK: - Layout

    /// When the open panel shrinks, the pointer may end up outside it; don't close right away.
    private func sizeChanged(large: Bool) {
        graceUntil = !large && model.isExpanded ? Date().addingTimeInterval(Self.shrinkGracePeriod) : nil
    }

    // MARK: - Hover (spec N-2…N-4)

    /// Area that opens the panel: the notch, or the whole peek while a notification shows.
    var hoverZone: CGRect {
        let geometry = model.geometry
        return reachingDown(notifications.peek == nil
            ? geometry.hoverZone : geometry.keepOpenZone(for: notifications.peekSize(in: geometry)))
    }

    var keepOpenZone: CGRect {
        reachingDown(model.geometry.keepOpenZone(for: model.openSize))
    }

    /// A pill floats a little below the top edge: its zones reach that much further (spec D-7).
    var pillGap: CGFloat {
        settings.externalStyle == .pill && !model.geometry.hasPhysicalNotch ? NotchView.pillGap : 0
    }

    private func reachingDown(_ zone: CGRect) -> CGRect {
        CGRect(x: zone.minX, y: zone.minY - pillGap, width: zone.width, height: zone.height + pillGap)
    }

    private func pointerMoved() {
        guard !model.isHiddenForMissionControl else { return }
        if callIsShown {
            updateCallInteraction()
        } else if model.isExpanded {
            evaluatePointerWhileExpanded()
        } else if handleDevicePeek(at: NSEvent.mouseLocation) {
            // A device notice under the notch (spec DV-6).
        } else if handleFileDrag(at: NSEvent.mouseLocation) {
            // Files dragged onto the notch (spec FT-1).
        } else if opens(at: NSEvent.mouseLocation) {
            hideStrip()
            setHoveredIndicator(nil)
            setHoveredBadge(nil)
            expand(preview: settings.hoverPreview, smart: true)
        } else if handleStrip(at: NSEvent.mouseLocation) {
            // On the module strip or the band that shows it (spec MS-1).
        } else if !model.isHiddenForFullScreen {
            updateHoveredIndicator()
        }
    }

    private func evaluatePointerWhileExpanded() {
        guard model.isExpanded else { return }
        if model.isShowingDropZone { endDropZoneIfDragEnded() } else { showDropZoneOverOpenNotch() }
        followFocusOntoNotch()
        // A panel that just shrank under the pointer keeps its former area until the pointer
        // leaves it (spec N-20).
        let inSticky = stickyZone?.contains(NSEvent.mouseLocation) ?? false
        if !inSticky { stickyZone = nil }
        // While a mouse button is down (e.g. dragging a slider) the panel stays open.
        let isInside = keepOpenZone.contains(NSEvent.mouseLocation) || inSticky || NSEvent.pressedMouseButtons != 0
        // The window is larger than the visible panel: let clicks around the panel through.
        panel.ignoresMouseEvents = !isInside
        if isInside { isHeldOpen = false }
        if model.isHeldByClick { watchClicksOutsideSettings() }
        if isInside || isHeldOpen || model.keepsOpen {
            graceUntil = nil
            cancelClose()
        } else if let graceUntil, graceUntil > Date() {
            cancelClose()
        } else {
            scheduleClose()
        }
    }

    /// - Parameter preview: show only the small preview first (spec PV-1).
    ///   - smart: opened by hover: the module may follow what is going on (spec SO-1).
    func expand(preview: Bool = false, smart: Bool = false) {
        cancelClose()
        graceUntil = nil
        panel.ignoresMouseEvents = false
        calendar.panelDidOpen()
        Haptics.perform(.open, settings: settings)
        // Opened from a notification peek: that sender's new messages (spec E-4).
        let stack = notifications.peek.map(notifications.related(to:)) ?? []
        let canReply = stack.last.map(notifications.canReply(to:)) ?? false
        if smart, stack.isEmpty, notices.notice?.opensChat != true { applySmartOpening() }
        let stackHeight = stack.isEmpty ? nil : notifications.stackHeight(for: stack, notchHeight: model.geometry.notchSize.height)
        withAnimation(Self.animation) { model.setExpanded(true, presenting: stack, canReply: canReply, stackHeight: stackHeight) }
        notifications.clearPeek()
        startHoverTimer()
        if preview, stack.isEmpty, notices.notice?.opensChat != true { startPreview() }
        showAnswerIfReady()
    }

    func collapse() {
        stickyZone = nil
        cancelClose()
        stopHoverTimer()
        graceUntil = nil
        isHeldOpen = false
        previewTask?.cancel()
        previewTask = nil
        panel.ignoresMouseEvents = true
        if model.isShowingNotifications { notifications.markSeen(model.notifications) }
        // Only an open panel ends the filter; the closed panels of other displays leave it.
        if model.isExpanded { notifications.clearFocus() }
        OpenMenus.closeAll()
        stopWatchingClicksOutsideSettings()
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
            if isOutside, !self.isHeldOpen, !self.model.keepsOpen {
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
    func startHoverTimer() {
        guard hoverTimer == nil else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        RunLoop.main.add(timer, forMode: .common)
        timer.tolerance = timer.timeInterval * 0.2
        hoverTimer = timer
    }

    func stopHoverTimer() {
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
        case .keyDown:
            return handleKey(event)
        default:
            pointerMoved()
            return false
        }
    }
}

// MARK: - Start and stop

extension NotchController {
    func start() {
        let frame = model.geometry.rect(for: model.geometry.windowSize)
        panel.setFrame(frame, display: true)
        glassPanel.setFrame(frame, display: true)
        glassPanel.orderFrontRegardless()
        panel.orderFrontRegardless()
        panel.addChildWindow(glassPanel, ordered: .below)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        // Scrolling while the panel is closed goes to other apps; watch it for the swipe up that
        // closes a meeting announcement (spec K-8f).
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            MainActor.assumeIsolated { _ = self?.handleCollapsedScroll(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .scrollWheel, .keyDown]) { [weak self] event in
            guard let self else { return event }
            let consumed = MainActor.assumeIsolated { self.handleLocal(event) }
            return consumed ? nil : event
        }
        sizeObserver = model.$isLarge.dropFirst().removeDuplicates().sink { [weak self] large in
            MainActor.assumeIsolated { self?.sizeChanged(large: large) }
        }
        chatObserver = chat.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.chatChanged() }
            }
        }
        chatChanged()
        startFullScreenChecks()
        OpenMenus.start()
        FileDragWatcher.shared.start()
        FileDragWatcher.shared.observe { [weak self] in self?.fileDragTick() }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Only a safety net: the animation follows the swipe itself.
            MainActor.assumeIsolated {
                self?.spaceSwipeLifted()
                self?.checkFullScreen()
            }
        }
        callObserver = calls.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.callChanged() }
            }
        }
        observeModel()
    }

    /// Fires before the change; the new state is looked at on the next run loop turn.
    private func observeModel() {
        followQuickLook()
        settingsObserver = model.objectWillChange.sink { [weak self] in
            let before = MainActor.assumeIsolated { self?.model.isExpanded == true ? self?.keepOpenZone : nil }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.updateKeyboardFocus()
                    self?.keepShrunkArea(before)
                }
            }
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        scrollMonitor = nil
        globalMonitor = nil
        localMonitor = nil
        sizeObserver = nil
        callObserver = nil
        chatObserver = nil
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
        settingsObserver = nil
        closeTask?.cancel()
        stopHoverTimer()
        stopFullScreenChecks()
        panel.removeChildWindow(glassPanel)
        glassPanel.orderOut(nil)
        glassPanel.close()
        panel.orderOut(nil)
        panel.close()
    }
}
