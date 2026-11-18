import AppKit
import ApplicationServices

/// Mission Control on and off (spec N-19). There is no public event; the Dock announces it to
/// Accessibility clients ("AXExposeShowAllWindows" … "AXExposeExit"), which Dynotch already is.
@MainActor
final class MissionControlWatcher {
    private var observer: AXObserver?
    private var dockPID: pid_t = 0
    private var launchObserver: NSObjectProtocol?
    private let changed: (Bool) -> Void

    nonisolated private static let showing = ["AXExposeShowAllWindows", "AXExposeShowFrontWindows", "AXExposeShowDesktop"]
    nonisolated private static let exit = "AXExposeExit"

    init(changed: @escaping (Bool) -> Void) {
        self.changed = changed
    }

    func start() {
        attach()
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
        changed(Self.isShowing(after: name))
    }

    nonisolated static func isShowing(after notification: String) -> Bool {
        showing.contains(notification)
    }
}
