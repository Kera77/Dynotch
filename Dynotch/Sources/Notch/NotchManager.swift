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
    private var menuBarPoller: Poller?
    private var activationObserver: NSObjectProtocol?
    private var isMeasuring = false

    init(services: AppServices, openSettings: @escaping () -> Void) {
        self.services = services
        self.openSettings = openSettings
    }

    func start() {
        rebuildIfNeeded()
        // The open Music module or the dropped-down player shows the new track itself (spec MU-10).
        services.music.holdsAnnouncement = { [weak self] in
            self?.controllers.contains {
                ($0.model.isExpanded && $0.model.currentFeature == .music) || $0.showsMusicDropdown
            } ?? false
        }
        let monitor = SpaceSwipeMonitor { [weak self] phase in
            self?.spaceSwipe(phase)
        }
        monitor.onVerticalSwipe = { [weak self] progress, ended in self?.missionControl?.swiped(progress: progress, ended: ended) }
        monitor.start()
        spaceSwipes = monitor
        // Mission Control: the notch would cover the Spaces along the top (spec N-19).
        let missionControl = MissionControlWatcher { [weak self] shown in
            self?.controllers.forEach { $0.setHiddenForMissionControl(shown) }
            MenuBarTintService.shared.setHiddenForMissionControl(shown)
        }
        missionControl.start()
        self.missionControl = missionControl
        // Sharing the screen: nothing of the notch for the viewers (spec N-21).
        // Screenshots and macOS recordings may show it; meeting apps never (spec N-21b).
        let sharing = ScreenShareWatcher { [weak self] _, meeting in
            self?.controllers.forEach { $0.setScreenShared(meeting) }
        }
        sharing.checked = { meeting in Self.hideFromSharing(meeting) }
        sharing.start()
        screenShare = sharing
        watchMenuBar()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildIfNeeded()
                self?.measureMenuBar()
            }
        }
    }

    /// Dynotch's windows are left out of a meeting share (spec N-21, N-21c). The window server
    /// applies a new sharing type to a window already on screen only when the window is put on
    /// screen again, so a changed window is ordered out and back in, back to front, keeping the
    /// order. Windows opened later get it at the next look.
    static func hideFromSharing(_ hidden: Bool) {
        let type: NSWindow.SharingType = hidden ? .none : .readOnly
        let changed = NSApp.windows.filter { $0.sharingType != type }
        guard !changed.isEmpty else { return }
        changed.forEach { $0.sharingType = type }
        guard hidden else { return }
        // Front to back, the app's windows on screen (panels too).
        let numbers = (NSWindow.windowNumbers(options: []) ?? []).map(\.intValue)
        let ordered = numbers.reversed().compactMap { number in changed.first { $0.windowNumber == number } }
        for window in ordered where window.isVisible {
            window.orderOut(nil)
            window.orderFrontRegardless()
        }
        DiagnosticsLog.append("spaces", "hidden from the share: \(changed.count) window(s)")
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

    /// The module switcher, on the display under the pointer (spec QS-4); not during Mission
    /// Control, which a swipe up may open too (spec QS-9).
    func showModuleSwitcher(_ shown: Bool) {
        if shown {
            guard let controller = pointerController, !controller.model.isHiddenForMissionControl else { return }
            controller.showModuleSwitcher(services.switcher.modules)
        } else {
            controllers.filter(\.model.showsModuleSwitcher).forEach { $0.hideSwitcher() }
        }
    }

    /// The chosen module, opened like its shortcut (spec QS-6).
    func openFromModuleSwitcher(_ feature: FeatureID, pinned: Bool) {
        let shown = controllers.first(where: \.model.showsModuleSwitcher)
        guard let controller = shown ?? pointerController, !controller.model.isHiddenForMissionControl else {
            shown?.hideSwitcher()
            return
        }
        controller.openFromModuleSwitcher(feature, pinned: pinned)
    }

    private var pointerController: NotchController? {
        let pointer = NSEvent.mouseLocation
        return controllers.first { $0.model.geometry.screenFrame.contains(pointer) } ?? controllers.first
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

    /// The notch models of every display, for the tour's practice steps (spec OB-24).
    var notchModels: [NotchViewModel] { controllers.map(\.model) }

    /// Closes every open notch (the tour starts or moves on, spec OB-10).
    func collapseAll() {
        controllers.filter(\.model.isExpanded).forEach { $0.collapse() }
    }

    func togglePin() {
        let pointer = NSEvent.mouseLocation
        let controller = controllers.first { $0.model.isExpanded }
            ?? controllers.first { $0.model.geometry.screenFrame.contains(pointer) } ?? controllers.first
        controller?.togglePin()
    }

    /// The menu bar is measured when another app becomes active (its menus change), when the
    /// displays or the badges change, and every 15 s in case, so the badges never cover its items
    /// (spec B-8, RF-12).
    private func watchMenuBar() {
        let badges = services.badges
        let poller = Poller(
            every: Self.menuBarFallback, isActive: { !badges.visible.isEmpty }, action: { [weak self] in self?.measureMenuBar() }
        )
        poller.start()
        menuBarPoller = poller
        badges.onVisibleChange = { [weak self] in
            self?.menuBarPoller?.reevaluate()
            self?.measureMenuBar()
        }
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

    private static let menuBarFallback: TimeInterval = 15

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
        // No notch on an iPad used as a display (spec TB-10); every display if only that is left.
        let others = NSScreen.screens.filter { !SidecarDisplay.isTablet($0) }
        let screens = others.isEmpty ? NSScreen.screens : others
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
