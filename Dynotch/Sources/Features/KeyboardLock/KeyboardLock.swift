import AppKit
import ApplicationServices
import Observation

/// Blocks every key press while on, so the keyboard can be cleaned without typing (spec KL-1…KL-3).
/// Only the mouse can turn it off again.
@MainActor
@Observable
final class KeyboardLock {
    private(set) var isLocked = false

    @ObservationIgnored private var tap: CFMachPort?
    @ObservationIgnored private var tapSource: CFRunLoopSource?

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
    }

    private func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private func unlock() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        tap = nil
        tapSource = nil
        isLocked = false
    }
}
