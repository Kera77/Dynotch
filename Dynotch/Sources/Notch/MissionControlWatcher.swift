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
    private static let slowPollInterval: TimeInterval = 1

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
        // The Dock's notices arrive: the window list is only a slower safety net now.
        if let watch { WindowListMonitor.shared.setInterval(Self.slowPollInterval, for: watch) }
        set(Self.isShowing(after: name))
    }

    private func poll(_ windows: [ListedWindow]) {
        set(Self.isMissionControl(windows, screens: NSScreen.screens.map(\.frame)))
    }

    private func set(_ shown: Bool) {
        guard shown != isShown else { return }
        isShown = shown
        DiagnosticsLog.append("spaces", shown ? "Mission Control shown" : "Mission Control closed")
        changed(shown)
    }

    /// A Dock window named "Dock" in the Dock's layer covering a whole display.
    nonisolated static func isMissionControl(_ windows: [ListedWindow], screens: [CGRect]) -> Bool {
        windows.contains { window in
            guard window.owner == "Dock", window.layer == 20 else { return false }
            return screens.contains { window.frame.width >= $0.width && window.frame.height >= $0.height * 0.9 }
        }
    }

    nonisolated static func isShowing(after notification: String) -> Bool {
        showing.contains(notification)
    }
}
