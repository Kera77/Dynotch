import AppKit
import ApplicationServices
import Combine

/// Blocks every key press while on, so the keyboard can be cleaned without typing (spec KL-1…KL-3).
/// The mouse turns it off again; it also ends by itself after a few minutes, or when Esc is held
/// for a few seconds (spec RF-4).
@MainActor
final class KeyboardLock: ObservableObject {
    @Published private(set) var isLocked = false

    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var autoUnlock: Task<Void, Never>?
    private var escapeDown: Date?

    /// The lock ends by itself after this long (spec RF-4).
    static let maximumDuration: Duration = .seconds(180)
    /// Holding Esc this long ends it too (spec RF-4).
    nonisolated static let escapeHold: TimeInterval = 3
    nonisolated private static let escapeKey: Int64 = 53

    func toggle() {
        if isLocked {
            unlock()
        } else {
            lock()
        }
    }

    private func lock() {
        guard tap == nil else { return }
        // Keys, modifiers, and the media keys (NX_SYSDEFINED).
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue) | CGEventMask(1 << 14)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                let lock = Unmanaged<KeyboardLock>.fromOpaque(refcon).takeUnretainedValue()
                MainActor.assumeIsolated { lock.reenable() }
                return Unmanaged.passUnretained(event)
            }
            if type == .keyDown || type == .keyUp, event.getIntegerValueField(.keyboardEventKeycode) == KeyboardLock.escapeKey {
                let lock = Unmanaged<KeyboardLock>.fromOpaque(refcon).takeUnretainedValue()
                MainActor.assumeIsolated { lock.escape(isDown: type == .keyDown) }
            }
            return nil
        }
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            DiagnosticsLog.append("keyboard-lock", "tap not created (Accessibility: \(AXIsProcessTrusted()))")
            NSSound.beep()
            return
        }
        let source = CFMachPortCreateRunLoopSource(nil, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        tap = created
        tapSource = source
        isLocked = true
        escapeDown = nil
        autoUnlock = Task { [weak self] in
            try? await Task.sleep(for: Self.maximumDuration)
            guard !Task.isCancelled, let self, self.isLocked else { return }
            DiagnosticsLog.append("keyboard-lock", "unlocked after the time limit")
            self.unlock()
        }
    }

    /// Esc held down (its key repeats keep coming) long enough unlocks; letting go starts over.
    private func escape(isDown: Bool) {
        guard isDown else {
            escapeDown = nil
            return
        }
        let now = Date()
        guard let since = escapeDown else {
            escapeDown = now
            return
        }
        guard KeyboardLockRules.isHeldLongEnough(since: since, now: now) else { return }
        DiagnosticsLog.append("keyboard-lock", "unlocked with Esc")
        unlock()
    }

    private func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private func unlock() {
        autoUnlock?.cancel()
        autoUnlock = nil
        escapeDown = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        tap = nil
        tapSource = nil
        isLocked = false
    }
}

enum KeyboardLockRules {
    static func isHeldLongEnough(since: Date, now: Date) -> Bool {
        now.timeIntervalSince(since) >= KeyboardLock.escapeHold
    }
}
