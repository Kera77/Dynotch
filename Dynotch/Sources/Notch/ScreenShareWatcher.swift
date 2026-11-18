import AppKit

/// Is the screen being shared or recorded (spec N-21)? There is no public signal; the sharing
/// apps' own indicator windows tell it: the "… is sharing your screen." bar of Chrome-based
/// browsers, the "Sharing Indicator" of Firefox and Zen, the share bars of Zoom and Teams, and
/// macOS's own recording controls.
@MainActor
final class ScreenShareWatcher {
    private var timer: Timer?
    private var isSharing = false
    private let changed: (Bool) -> Void
    private static let interval: TimeInterval = 2

    init(changed: @escaping (Bool) -> Void) {
        self.changed = changed
    }

    func start() {
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        timer.tolerance = Self.interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        check()
    }

    private func check() {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        let sharing = Self.isSharing(windows ?? [])
        guard sharing != isSharing else { return }
        isSharing = sharing
        DiagnosticsLog.append("spaces", sharing ? "screen sharing started" : "screen sharing ended")
        changed(sharing)
    }

    /// Whether one of the windows is a sharing indicator.
    nonisolated static func isSharing(_ windows: [[String: Any]]) -> Bool {
        windows.contains { window in
            let owner = (window[kCGWindowOwnerName as String] as? String ?? "").lowercased()
            let name = (window[kCGWindowName as String] as? String ?? "").lowercased()
            if name.contains("is sharing your screen") || name.contains("is sharing a window") || name.contains("is sharing this tab") {
                return true
            }
            if name.contains("sharing indicator") { return true }
            if owner.contains("zoom"), name.contains("share toolbar") || name.contains("share statusbar") { return true }
            if owner.contains("teams"), name.contains("sharing control bar") { return true }
            return owner == "screencaptureui" && (window[kCGWindowLayer as String] as? Int ?? 0) > 0
        }
    }
}
