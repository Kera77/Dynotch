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
        guard NSEvent.pressedMouseButtons == 0,
              !NSApp.windows.contains(where: { $0.isKeyWindow && $0.isVisible }),
              let point = CGEvent(source: nil)?.location,
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
        guard attempts.shouldTry(target.id) else { return }
        if SkyLightFocus.focusWithoutRaise(
            pid: target.pid, windowID: target.id, focusedPID: frontPID, focusedWindowID: focusedWindow
        ) {
            lastFocused = target.id
        }
    }
}
