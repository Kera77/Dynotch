import AppKit
import SwiftUI

/// Owns the notch panel of one display and turns pointer/trackpad input into panel state.
@MainActor
final class NotchController {
    static var animation: Animation { Motion.spring }
    /// The window switcher drops down much faster than the notch opens (spec AS-15).
    static var switcherAnimation: Animation { AppleStyle.spring(response: 0.16, dampingFraction: 0.88) }
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
    let clipboard: ClipboardStore
    let devices: DeviceWatcher
    let badges: BadgeService
    let calls: CallService
    private var callObserver: ChangeObservation?
    var callIsShown = false
    let notices: NoticeService
    let chat: ClaudeChatService
    let battery: BatteryService
    let beeper: BeeperService
    let music: MusicService
    let stats: StatsService
    let screenshots: ScreenshotService
    private var chatObserver: ChangeObservation?
    private var spaceObserver: NSObjectProtocol?
    var gatherTask: Task<Void, Never>?
    var gatherStarted: Date?
    /// Opened with a shortcut: stays open until the pointer has been on the panel (spec SC-1).
    var isHeldOpen = false
    /// The larger area of before a size change made by a click in the panel: still "inside"
    /// until the pointer leaves it (spec N-20).
    var stickyZone: CGRect?
    var previewSwipe = VerticalSwipe()
    var wingsSwipes = WingsSwipes()
    let openSettings: () -> Void
    let model: NotchViewModel
    let panel: NotchPanel
    /// The glass behind the panel, in a window that never takes the keyboard (spec D-6).
    let glassPanel: GlassPanel

    private var globalMonitor: Any?
    private var scrollMonitor: Any?
    /// A click in another app takes the keyboard from the panel (spec F-15b).
    private var keyClickMonitor: Any?
    var announcementSwipe = VerticalSwipe()
    private var localMonitor: Any?
    var settingsObserver: ChangeObservation?
    var beeperListObserver: ChangeObservation?
    private var hoverTimer: Timer?
    var fullScreenWatch: WindowListMonitor.Token?
    private var closeTask: Task<Void, Never>?
    private var graceUntil: Date?
    /// One swipe over the panel switches one module, after 45 pt (spec S-1, M-14).
    var swipe = SwipeDetector(threshold: 45)
    var dayStepper = DayStepper()
    /// Over the icons ~80 pt of finger movement a module, one by one; momentum only on the day strip (spec M-12, M-17, M-21, K-17).
    var switcherStepper = DayStepper(stepWidth: 80, momentumScale: 0.5)
    var switcherQueue = StepQueue(maxPending: 5), dayQueue = StepQueue(maxPending: 7), stepTimer: Timer?, switcherFlick = FlickTracker()
    /// The swipe over the feature icons reached an end: the rest of it is ignored (spec M-13).
    var switcherReachedEnd = false
    /// A swipe over the tasks counter's list picker (spec R-19).
    var taskListSwipe = SwipeDetector()
    /// The current trackpad gesture already switched features: it must not step days too.
    var gestureSwitchedFeature = false
    /// After the announcement was swiped away the pointer is still on it: no hover details until
    /// it leaves, so only the countdown stays (spec K-8f).
    var suppressIndicatorHover = false
    /// A notice beside the notch was just put away: the icons under it wait (spec PV-59).
    var indicatorHoverPausedUntil: Date?
    var wasExpanded = false, keyboardBackPending = false
    /// The pointer is on the notice under the notch: its X can be clicked (spec CN-5b).
    var isOverNotice = false
    /// The pointer is on a small notice beside the closed notch in Wings mode (spec PV-38).
    var isOverWingsPeek = false
    /// A notice beside the notch was put away: the notch unfolds again after it (spec PV-48).
    var peekFold: UUID?
    /// Since when the pointer rests on the notch while a small notice hangs under it (spec PV-71).
    var dropDownHoverSince: Date?
    var dropDownHoverTask: Task<Void, Never>?
    /// When the pointer was last on a badge, indicator or counter beside the closed notch (spec N-24).
    var besideRowSeenAt: Date?
    /// Since when the pointer, come from the row beside, rests on the notch (spec N-24).
    var sideArrivalSince: Date?
    /// Another icon the pointer is on while a drop-down is open, and since when (spec N-23).
    var pendingHover: (target: String, since: Date)?
    /// The question notice whose app was already brought forward (spec CQ-3).
    var activatedQuestion: Date?
    /// Watches for the click outside that closes the settings (spec C-6).
    var settingsClickMonitor: Any?
    /// Waits for the pointer to rest on the notch's bottom edge (spec MS-2).
    var stripTask: Task<Void, Never>?
    /// Opens the batteries after resting on a Bluetooth notice, so it can be flicked away first.
    var deviceHoverTask: Task<Void, Never>?

    init(screen: NSScreen, services: AppServices, openSettings: @escaping () -> Void) {
        settings = services.settings
        calendar = services.calendar
        notifications = services.notifications
        claudeUsage = services.claudeUsage
        reminders = services.reminders
        tasks = services.tasks
        calculator = services.calculator
        tray = services.tray
        clipboard = services.clipboard
        devices = services.devices
        badges = services.badges
        calls = services.calls
        notices = services.notices
        chat = services.chat
        battery = services.battery
        beeper = services.beeper
        music = services.music
        stats = services.stats
        screenshots = services.screenshots
        self.openSettings = openSettings
        let geometry = Self.geometry(for: screen)
        model = NotchViewModel(settings: settings, geometry: geometry, screenName: screen.localizedName)
        // The window always has the large size, so switching views never resizes it; outside
        // the visible panel it ignores the mouse (see evaluatePointerWhileExpanded).
        let windowRect = geometry.rect(for: geometry.windowSize)
        panel = NotchPanel(contentRect: windowRect)
        glassPanel = GlassPanel(level: panel.level)

        let rootView = makeRootView(services)
        observeBeeperList(services.beeper)
        model.requestCollapse = { [weak self] in self?.collapse() }
        model.requestKeyboard = { [weak self] in self?.takeKeyboardForReply() }
        model.recheckPointer = { [weak self] in self?.evaluatePointerWhileExpanded() }
        panel.keepsKeyboard = { [weak self] point in self?.keepOpenZone.contains(point) ?? true }
        panel.letGoOfKeyboard = { [weak self] in self?.giveKeyboardBack(evenIfNotKey: true) }
        var glassView = rootView
        glassView.layer = .glass
        glassPanel.contentView = NSHostingView(rootView: glassView)
        let hosting = FirstMouseHostingView(rootView: rootView)
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: windowRect.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        model.passing.capture = { [weak self, weak hosting] in hosting.flatMap { self?.snapshotPage(in: $0) } }
    }

    // MARK: - Layout

    /// When the open panel shrinks, the pointer may end up outside it; don't close right away.
    private func sizeChanged(large: Bool) {
        graceUntil = !large && model.isExpanded ? Date().addingTimeInterval(Self.shrinkGracePeriod) : nil
    }

    // MARK: - Hover (spec N-2…N-4)

    func pointerMoved() {
        guard !model.isHiddenForMissionControl else { return }
        updateWingsPeekHover(at: NSEvent.mouseLocation)
        if callIsShown {
            updateCallInteraction()
        } else if model.isExpanded {
            evaluatePointerWhileExpanded()
        } else if handleScreenshotPeek(at: NSEvent.mouseLocation) {
            // The shot just made opens into the editor (spec SH-6).
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
        } else {
            settleAfterHover()
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
        // A menu opened from the panel reaches outside it: the panel stays while it is open (spec N-22).
        let isInside = keepOpenZone.contains(NSEvent.mouseLocation) || inSticky || NSEvent.pressedMouseButtons != 0
            || OpenMenus.isOpen
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
    func expand(preview: Bool = false, smart: Bool = false, animation: Animation = NotchController.animation) {
        cancelClose()
        graceUntil = nil
        if model.hidesGlass { model.hidesGlass = false } // Hidden only around the switcher (spec AS-18).
        panel.ignoresMouseEvents = false
        calendar.panelDidOpen()
        Haptics.perform(.open, settings: settings)
        // Opened from a notification peek: that sender's new messages (spec E-4).
        let stack = notifications.peek.map(notifications.related(to:)) ?? []
        let canReply = stack.last.map(notifications.canReply(to:)) ?? false
        // A Google Chat card without a notification reads its messages from the web app (spec GW-5c).
        notifications.cardOpened(stack)
        if smart, stack.isEmpty, notices.notice?.opensChat != true { applySmartOpening() }
        let stackHeight = stack.isEmpty ? nil : notifications.stackHeight(for: stack, notchHeight: model.geometry.notchSize.height)
        withAnimation(animation) { model.setExpanded(true, presenting: stack, canReply: canReply, stackHeight: stackHeight) }
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
        panel.ignoresMouseEvents = true
        if model.isShowingNotifications { notifications.markSeen(model.notifications) }
        // Google Chat cards closed without a reply go back to unread (spec GW-17).
        if model.isExpanded { notifications.allCardsClosed() }
        // Only an open panel ends the filter; the closed panels of other displays leave it.
        if model.isExpanded { notifications.clearFocus() }
        OpenMenus.closeAll()
        stopWatchingClicksOutsideSettings()
        withAnimation(Self.animation) { model.setExpanded(false) }
    }

    private func scheduleClose() {
        guard closeTask == nil else { return }
        let delay = model.isPreview ? min(settings.closeDelay, 0.1) : settings.closeDelay
        closeTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled, let self else { return }
            self.closeTask = nil
            let isOutside = !self.keepOpenZone.contains(NSEvent.mouseLocation) && NSEvent.pressedMouseButtons == 0
            if isOutside, !self.isHeldOpen, !self.model.keepsOpen, !OpenMenus.isOpen {
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
        hoverTimer = RepeatingTimer.start(every: 0.05) { [weak self] in self?.pointerMoved() }
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
            // No module switching under the screenshot editor (spec SH-7).
            // Wings: a swipe down opens fully, up on the top row folds back (spec PV-5, PV-12).
            if let handled = handleWingsScroll(event) { return handled }
            return model.editor == nil && handleScroll(event)
        case .keyDown:
            return handleKey(event)
        case .leftMouseUp:
            keyboardBackAfterWingsClick()
            return false
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
        keyClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.clickedInAnotherApp() }
        }
        let localEvents: NSEvent.EventTypeMask = [.mouseMoved, .scrollWheel, .keyDown, .leftMouseUp]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: localEvents) { [weak self] event in
            guard let self else { return event }
            let consumed = MainActor.assumeIsolated { self.handleLocal(event) }
            return consumed ? nil : event
        }
        model.onLargeChange = { [weak self] large in self?.sizeChanged(large: large) }
        chatObserver = observeChanges { [chat] in _ = chat.isTall } onChange: { [weak self] in self?.chatChanged() }
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
                self?.checkFullScreenNow()
            }
        }
        callObserver = observeChanges { [calls] in
            _ = calls.call
            _ = calls.isComposing
        } onChange: { [weak self] in
            self?.callChanged()
        }
        observeModel()
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        if let keyClickMonitor { NSEvent.removeMonitor(keyClickMonitor) }
        scrollMonitor = nil
        globalMonitor = nil
        localMonitor = nil
        model.onLargeChange = { _ in }
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
