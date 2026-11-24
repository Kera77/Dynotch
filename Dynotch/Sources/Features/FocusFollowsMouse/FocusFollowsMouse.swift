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
        settingsObserver = settings.afterChange { [weak self] in self?.apply() }
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

    private func focusWindowUnderPointer(afterLettingGo: Bool = false) {
        // Never while dragging or selecting, and never take the keyboard from a Dynotch panel
        // someone is typing in (spec F-4).
        guard NSEvent.pressedMouseButtons == 0 else { return }
        guard let point = CGEvent(source: nil)?.location,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]]
        else { return }
        let windows = WindowPicker.screenWindows(from: info)
        if !afterLettingGo, letGoIfDynotchHoldsKeys(windows: windows) { return }
        if NSApp.windows.contains(where: FocusRules.takesKeyboard) {
            logSkip("a Dynotch window has the keyboard")
            return
        }
        guard let target = WindowPicker.window(at: point, in: windows, ownPID: getpid()) else { return }

        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let focusedWindow = frontPID.flatMap(SkyLightFocus.focusedWindowID(of:))
        // Windows, not apps (spec F-13): inside the active app too, but never away from a
        // dialog or sheet, nor onto a small pop-up, which made them flicker before (spec F-8).
        let sameApp = target.pid == frontPID
        let focusedIsDialog = sameApp && frontPID.map(SkyLightFocus.hasFocusedDialog(pid:)) == true
        // Asked only inside the active app, and only when another of its windows is under the pointer.
        let targetIsStandard = sameApp && target.id != focusedWindow
            && SkyLightFocus.isStandardWindow(pid: target.pid, windowID: target.id, size: target.bounds.size)
        // Dynotch just let go: the window may count as focused while it does not get the keys
        // yet, so it is made key for real (spec F-18).
        let reassert = afterLettingGo && sameApp && target.id == focusedWindow && !focusedIsDialog
        guard reassert || FocusRules.shouldSwitch(
            target: target, frontPID: frontPID, focusedWindow: focusedWindow, focusedIsDialog: focusedIsDialog,
            targetIsStandard: targetIsStandard
        ) else {
            attempts.reset()
            return
        }
        guard attempts.shouldTry(target.id) else {
            logSkip("the window did not keep the focus twice; waiting for another window")
            return
        }
        if SkyLightFocus.focusWithoutRaise(
            pid: target.pid, windowID: target.id,
            focusedPID: reassert ? nil : frontPID, focusedWindowID: reassert ? nil : focusedWindow
        ) {
            lastFocused = target.id
        } else {
            logSkip("the window server refused the switch")
        }
    }

    /// The open notch lets go of the keyboard once the pointer rests outside it, whether a
    /// module asked for the keys (spec F-17) or Dynotch only became active, e.g. after a click
    /// in the System module, and typing went nowhere (spec F-18). Not while a Dynotch menu is open.
    /// - Returns: true when it let go; the switch follows a moment later.
    private func letGoIfDynotchHoldsKeys(windows: [ScreenWindow]) -> Bool {
        let panels = NSApp.windows.compactMap { $0 as? NotchPanel }
        let mouse = NSEvent.mouseLocation
        // A closed panel may still report itself key without getting any keys (spec F-11).
        let keyPanel = panels.first { $0.isKeyWindow && $0.isVisible && $0.allowsKey }
        let otherKey = NSApp.windows.contains { $0.isKeyWindow && $0.isVisible && !($0 is NotchPanel) }
        guard !otherKey, keyPanel != nil || NSApp.isActive,
              !FocusRules.hasOpenMenu(in: windows, ownPID: getpid()),
              !panels.contains(where: { $0.isVisible && $0.keepsKeyboard(mouse) }),
              let panel = keyPanel ?? panels.first
        else { return false }
        DiagnosticsLog.append("focus", "letting go: panel key=\(keyPanel != nil) dynotch active=\(NSApp.isActive)")
        panel.letGoOfKeyboard()
        retryAfterLettingGo()
        return true
    }

    /// Once the notch has handed the keyboard back (it takes a moment), the window under the
    /// pointer gets it (spec F-17).
    private func retryAfterLettingGo() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.focusWindowUnderPointer(afterLettingGo: true)
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
