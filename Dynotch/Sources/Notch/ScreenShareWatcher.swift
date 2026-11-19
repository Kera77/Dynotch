import AppKit

/// Is the screen being shared or recorded (spec N-21)? There is no public signal; the sharing
/// apps' own indicator windows tell it: the "… is sharing your screen." bar of Chrome-based
/// browsers, the "Sharing Indicator" of Firefox and Zen, the share bars of Zoom and Teams, and
/// macOS's own recording controls.
@MainActor
final class ScreenShareWatcher {
    private var isSharing = false
    private let changed: (Bool) -> Void
    private static let interval: TimeInterval = 2

    init(changed: @escaping (Bool) -> Void) {
        self.changed = changed
    }

    func start() {
        WindowListMonitor.shared.subscribe(every: Self.interval) { [weak self] windows in self?.check(windows) }
    }

    private func check(_ windows: [ListedWindow]) {
        let sharing = Self.isSharing(windows)
        guard sharing != isSharing else { return }
        isSharing = sharing
        DiagnosticsLog.append("spaces", sharing ? "screen sharing started" : "screen sharing ended")
        changed(sharing)
    }

    /// Whether one of the windows is a sharing indicator.
    nonisolated static func isSharing(_ windows: [ListedWindow]) -> Bool {
        windows.contains { window in
            let owner = window.owner.lowercased()
            let name = window.name.lowercased()
            if name.contains("is sharing your screen") || name.contains("is sharing a window") || name.contains("is sharing this tab") {
                return true
            }
            if name.contains("sharing indicator") { return true }
            if owner.contains("zoom"), name.contains("share toolbar") || name.contains("share statusbar") { return true }
            if owner.contains("teams"), name.contains("sharing control bar") { return true }
            return owner == "screencaptureui" && window.layer > 0
        }
    }
}
