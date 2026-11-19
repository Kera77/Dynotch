import AppKit

/// Keeps one notch panel on every connected display and rebuilds them when displays change.
@MainActor
final class NotchManager {
    private let services: AppServices
    private let openSettings: () -> Void
    private var controllers: [NotchController] = []
    private var missionControl: MissionControlWatcher?
    private var screenShare: ScreenShareWatcher?
    private var screenObserver: NSObjectProtocol?
    private var signature = ""
    private var spaceSwipes: SpaceSwipeMonitor?
    private var menuBarTimer: Timer?
    private var activationObserver: NSObjectProtocol?
    private var isMeasuring = false

    init(services: AppServices, openSettings: @escaping () -> Void) {
        self.services = services
        self.openSettings = openSettings
    }

    func start() {
        rebuildIfNeeded()
        let monitor = SpaceSwipeMonitor { [weak self] phase in
            self?.spaceSwipe(phase)
        }
        monitor.start()
        spaceSwipes = monitor
        // Mission Control: the notch would cover the Spaces along the top (spec N-19).
        let missionControl = MissionControlWatcher { [weak self] shown in
            self?.controllers.forEach { $0.setHiddenForMissionControl(shown) }
        }
        missionControl.start()
        self.missionControl = missionControl
        // Sharing the screen: nothing of the notch for the viewers (spec N-21).
        let sharing = ScreenShareWatcher { [weak self] shared in
            self?.controllers.forEach { $0.setScreenShared(shared) }
            for window in NSApp.windows { window.sharingType = shared ? .none : .readOnly }
        }
        sharing.start()
        screenShare = sharing
        watchMenuBar()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildIfNeeded() }
        }
    }

    /// A shortcut opens the feature on the display the pointer is on (spec SC-1).
    func open(_ feature: FeatureID, pinned: Bool) {
        let pointer = NSEvent.mouseLocation
        let controller = controllers.first { $0.model.geometry.screenFrame.contains(pointer) } ?? controllers.first
        controller?.toggle(feature, pinned: pinned)
    }

    /// The pin shortcut (spec SC-3).
    /// The clipboard's items while its shortcut is held, on the display under the pointer (spec CB-3).
    func showClipboardPicker(_ shown: Bool) {
        let pointer = NSEvent.mouseLocation
        if shown {
            let controller = controllers.first { $0.model.geometry.screenFrame.contains(pointer) } ?? controllers.first
            controller?.showClipboardPicker()
        } else {
            controllers.filter(\.model.isShowingClipboardPicker).forEach { $0.hideClipboardPicker() }
        }
    }

    /// The screenshot editor, on the display under the pointer (spec SH-7, SH-11).
    func openScreenshotEditor(_ url: URL) {
        let pointer = NSEvent.mouseLocation
        let controller = controllers.first { $0.model.geometry.screenFrame.contains(pointer) } ?? controllers.first
        controller?.openScreenshotEditor(url, fromPeek: false)
    }

    /// The window switcher, on the display under the pointer (spec AS-6).
    func showSwitcher(_ shown: Bool) {
        let pointer = NSEvent.mouseLocation
        if shown {
            let controller = controllers.first { $0.model.geometry.screenFrame.contains(pointer) } ?? controllers.first
            controller?.showSwitcher(services.switcher)
        } else {
            controllers.filter(\.model.isShowingSwitcher).forEach { $0.hideSwitcher() }
        }
    }

    /// The pointer's display in window-list coordinates (top-left origin), for "only this display".
    static func pointerDisplayFrame() -> CGRect? {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }),
              let primary = NSScreen.screens.first
        else { return nil }
        let frame = screen.frame
        return CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
    }

    func togglePin() {
        let pointer = NSEvent.mouseLocation
        let controller = controllers.first { $0.model.isExpanded }
            ?? controllers.first { $0.model.geometry.screenFrame.contains(pointer) } ?? controllers.first
        controller?.togglePin()
    }

    /// The menu bar is measured when another app becomes active (its menus change) and every few
    /// seconds, so the badges never cover its items (spec B-8).
    private func watchMenuBar() {
        menuBarTimer = RepeatingTimer.start(every: 3) { [weak self] in self?.measureMenuBar() }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // The new app's menus appear a moment after it becomes active.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                MainActor.assumeIsolated { self?.measureMenuBar() }
            }
        }
        measureMenuBar()
    }

    private func measureMenuBar() {
        guard !isMeasuring, !services.badges.visible.isEmpty,
              let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        else { return }
        isMeasuring = true
        let own = ProcessInfo.processInfo.processIdentifier
        Task { [weak self] in
            let snapshot = await Task.detached { MenuBarSpace.snapshot(frontPID: front, ownPID: own) }.value
            guard let self else { return }
            self.isMeasuring = false
            self.controllers.forEach { $0.applyMenuBar(snapshot) }
        }
    }

    /// The swipe moves the Spaces of the display under the pointer, or of every display when
    /// they share their Spaces.
    private func spaceSwipe(_ phase: SpaceSwipe.Phase) {
        let pointer = NSEvent.mouseLocation
        let affected = NSScreen.screensHaveSeparateSpaces
            ? controllers.filter { $0.model.geometry.screenFrame.contains(pointer) }
            : controllers
        for controller in affected {
            switch phase {
            case .began: controller.spaceSwipeBegan()
            case .ended: controller.spaceSwipeLifted()
            case .changed: break
            }
        }
    }

    private func rebuildIfNeeded() {
        let screens = NSScreen.screens
        let newSignature = screens
            .map { "\($0.frame)|\($0.visibleFrame.maxY)|\($0.safeAreaInsets.top)" }
            .joined(separator: ";")
        guard newSignature != signature else { return }
        signature = newSignature

        controllers.forEach { $0.stop() }
        controllers = screens.map {
            NotchController(screen: $0, services: services, openSettings: openSettings)
        }
        controllers.forEach { $0.start() }
    }
}
