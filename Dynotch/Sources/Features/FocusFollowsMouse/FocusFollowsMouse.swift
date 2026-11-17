import AppKit
import Combine

/// Focus follows the mouse, without ever raising a window (spec F-1…F-6).
@MainActor
final class FocusFollowsMouse {
    private let settings: AppSettings
    private var monitor: Any?
    private var pending: Task<Void, Never>?
    private var settingsObserver: AnyCancellable?
    private var lastFocused: CGWindowID?
    private var attempts = FocusRules.Attempts()
    /// When each reason for not switching was last written to the log.
    private var lastSkipLog: [String: Date] = [:]

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        settingsObserver = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.apply() }
            }
        }
        apply()
    }

    private func apply() {
        let enabled = settings.focusFollowsMouse && SkyLightFocus.isAvailable
        if enabled, monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
                MainActor.assumeIsolated { self?.pointerMoved() }
            }
            DiagnosticsLog.append("focus", "on (Accessibility: \(AXIsProcessTrusted()))")
        } else if !enabled, let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
            pending?.cancel()
        }
        if settings.focusFollowsMouse, !SkyLightFocus.isAvailable {
            DiagnosticsLog.append("focus", "unavailable: window server functions not found")
        }
    }

    /// Waits until the pointer rests for the configured delay (spec F-3).
    private func pointerMoved() {
        pending?.cancel()
        let delay = settings.focusDelay
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.focusWindowUnderPointer()
        }
    }

    private func focusWindowUnderPointer() {
        // Never while dragging or selecting, and never take the keyboard from a Dynotch panel
        // someone is typing in (spec F-4).
        guard NSEvent.pressedMouseButtons == 0 else { return }
        if let window = NSApp.windows.first(where: FocusRules.takesKeyboard) {
            logSkip("a Dynotch window has the keyboard (\(type(of: window)))")
            return
        }
        guard let point = CGEvent(source: nil)?.location,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]]
        else { return }

        let windows = WindowPicker.screenWindows(from: info)
        guard let target = WindowPicker.window(at: point, in: windows, ownPID: getpid()) else { return }

        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        // Inside the active app nothing is done: the app decides which of its windows has the
        // focus. Switching there fought with dialogs and pop-ups and made them flicker (spec F-8).
        guard FocusRules.shouldSwitch(targetPID: target.pid, frontPID: frontPID) else {
            attempts.reset()
            return
        }
        let focusedWindow = frontPID.flatMap(SkyLightFocus.focusedWindowID(of:))
        guard attempts.shouldTry(target.id) else {
            logSkip("the window did not keep the focus twice; waiting for another window")
            return
        }
        if SkyLightFocus.focusWithoutRaise(
            pid: target.pid, windowID: target.id, focusedPID: frontPID, focusedWindowID: focusedWindow
        ) {
            lastFocused = target.id
        } else {
            logSkip("the window server refused the switch")
        }
    }

    /// Why focus did not follow, at most once a minute per reason (no app or window names).
    private func logSkip(_ reason: String) {
        let now = Date()
        guard now.timeIntervalSince(lastSkipLog[reason] ?? .distantPast) > 60 else { return }
        lastSkipLog[reason] = now
        DiagnosticsLog.append("focus", "skipped: \(reason)")
    }
}
