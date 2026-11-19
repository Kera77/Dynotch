import AppKit

/// Is the screen being shared or recorded (spec N-21)? There is no public signal; the sharing
/// apps' own indicator windows tell it: the "… is sharing your screen." bar of Chrome-based
/// browsers, the "Sharing Indicator" of Firefox and Zen, the share bars of Zoom and Teams, and
/// macOS's own recording controls.
@MainActor
final class ScreenShareWatcher {
    private var isSharing = false
    private var isMeeting = false
    /// Sharing at all; and shared by a meeting app, not macOS's own screenshot or recording tool.
    private let changed: (_ sharing: Bool, _ meeting: Bool) -> Void
    /// After every look at the windows, with whether a meeting app shares: windows Dynotch opened
    /// since are hidden from the share too (spec N-21c).
    var checked: ((_ meeting: Bool) -> Void)?
    private static let interval: TimeInterval = 2

    init(changed: @escaping (_ sharing: Bool, _ meeting: Bool) -> Void) {
        self.changed = changed
    }

    func start() {
        WindowListMonitor.shared.subscribe(every: Self.interval) { [weak self] windows in self?.check(windows) }
    }

    private func check(_ windows: [ListedWindow]) {
        let sharing = Self.isSharing(windows)
        let meeting = Self.isMeetingShare(windows)
        defer { checked?(meeting) }
        guard sharing != isSharing || meeting != isMeeting else { return }
        isSharing = sharing
        isMeeting = meeting
        DiagnosticsLog.append("spaces", sharing ? "screen sharing started (meeting: \(meeting))" : "screen sharing ended")
        changed(sharing, meeting)
    }

    /// Whether one of the windows is a sharing indicator.
    nonisolated static func isSharing(_ windows: [ListedWindow]) -> Bool {
        isMeetingShare(windows) || windows.contains { $0.owner.lowercased() == "screencaptureui" && $0.layer > 0 }
    }

    /// A browser, Zoom or Teams shares the screen. macOS's screenshot tool is left out: a
    /// screenshot may show the notch (spec N-21b).
    nonisolated static func isMeetingShare(_ windows: [ListedWindow]) -> Bool {
        windows.contains { window in
            let owner = window.owner.lowercased()
            let name = window.name.lowercased()
            if name.contains("is sharing your screen") || name.contains("is sharing a window") || name.contains("is sharing this tab") {
                return true
            }
            if name.contains("sharing indicator") { return true }
            if owner.contains("zoom"), name.contains("share toolbar") || name.contains("share statusbar") { return true }
            return owner.contains("teams") && name.contains("sharing control bar")
        }
    }
}
