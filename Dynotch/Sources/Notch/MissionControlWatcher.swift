import AppKit
import ApplicationServices

/// Mission Control on and off (spec N-19). There is no public event. While it shows, the Dock
/// puts a window named "Dock" over a whole display; a cheap look at the window list finds it.
/// The Dock's Accessibility notices ("AXExposeShowAllWindows" … "AXExposeExit") are a faster
/// path where macOS still sends them.
@MainActor
final class MissionControlWatcher {
    private var observer: AXObserver?
    private var dockPID: pid_t = 0
    private var launchObserver: NSObjectProtocol?
    private let changed: (Bool) -> Void
    private var watch: WindowListMonitor.Token?
    private var isShown = false
    private static let pollInterval: TimeInterval = 0.3
    /// How far the trackpad swipe must go before the notch leaves (spec N-19b).
    private static let swipeThreshold = 0.06
    private var verifyTask: Task<Void, Never>?
    /// The window list is not trusted while a swipe runs and until it is confirmed after it.
    private var swipeHold = false

    nonisolated private static let showing = ["AXExposeShowAllWindows", "AXExposeShowFrontWindows", "AXExposeShowDesktop"]
    nonisolated private static let exit = "AXExposeExit"

    init(changed: @escaping (Bool) -> Void) {
        self.changed = changed
    }

    func start() {
        attach()
        watch = WindowListMonitor.shared.subscribe(every: Self.pollInterval) { [weak self] windows in self?.poll(windows) }
        // The Dock restarts now and then (and after a crash): attach to the new one.
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == "com.apple.dock" else { return }
            MainActor.assumeIsolated { self?.attach() }
        }
    }

    private func attach() {
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
              dock.processIdentifier != dockPID
        else { return }
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        dockPID = dock.processIdentifier
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, notification, context in
            guard let context else { return }
            let watcher = Unmanaged<MissionControlWatcher>.fromOpaque(context).takeUnretainedValue()
            let name = notification as String
            MainActor.assumeIsolated { watcher.received(name) }
        }
        guard AXObserverCreate(dockPID, callback, &created) == .success, let created else {
            DiagnosticsLog.append("spaces", "Mission Control watch not created")
            return
        }
        let element = AXUIElementCreateApplication(dockPID)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.showing + [Self.exit] {
            AXObserverAddNotification(created, element, name as CFString, context)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
    }

    private func received(_ name: String) {
        set(Self.isShowing(after: name))
    }

    /// The up/down trackpad swipe: the notch leaves as Mission Control starts opening and comes
    /// back as it starts closing, without waiting for the window list. After the swipe the list
    /// confirms it, so a swipe given up halfway brings the notch back (spec N-19b).
    func swiped(progress: Double, ended: Bool) {
        swipeHold = true
        if progress <= -Self.swipeThreshold, !isShown {
            set(true)
        } else if progress >= Self.swipeThreshold, isShown {
            set(false)
        }
        guard ended else { return }
        verifyTask?.cancel()
        verifyTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            let windows = await Task.detached { WindowListMonitor.onScreenWindows() }.value
            guard !Task.isCancelled, let self else { return }
            self.swipeHold = false
            self.poll(windows)
        }
    }

    private func poll(_ windows: [ListedWindow]) {
        guard !swipeHold else { return }
        set(Self.isMissionControl(windows, screens: NSScreen.screens.map(\.frame)))
    }

    private func set(_ shown: Bool) {
        guard shown != isShown else { return }
        isShown = shown
        DiagnosticsLog.append("spaces", shown ? "Mission Control shown" : "Mission Control closed")
        changed(shown)
    }

    /// A Dock window named "Dock" in the Dock's layer covering a whole display, together with
    /// Mission Control's own windows (the Spaces bar, the shield behind the windows), which
    /// WindowManager puts up. The Dock puts up the same whole-display window when it slides in
    /// under the pointer; that alone is not Mission Control (spec N-19c).
    nonisolated static func isMissionControl(_ windows: [ListedWindow], screens: [CGRect]) -> Bool {
        let dock = windows.contains { window in
            guard window.owner == "Dock", window.layer == 20 else { return false }
            return screens.contains { window.frame.width >= $0.width && window.frame.height >= $0.height * 0.9 }
        }
        guard dock else { return false }
        return windows.contains { window in
            guard window.owner == "WindowManager", (1..<20).contains(window.layer) else { return false }
            return screens.contains { window.frame.width >= $0.width }
        }
    }

    nonisolated static func isShowing(after notification: String) -> Bool {
        showing.contains(notification)
    }
}
