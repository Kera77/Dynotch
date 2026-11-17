import AppKit
import ApplicationServices

/// The parts of the system's Space-switching swipe that matter here (spec N-10). macOS sends it
/// to the Dock as a "dock control" event; the field numbers are not documented by Apple.
enum SpaceSwipe {
    enum Phase: Equatable, Sendable {
        case began
        case changed
        case ended
    }

    /// Event type of dock control events (CGSEventType 30) and of gestures (29).
    static let dockControlType: UInt32 = 30
    static let gestureType: UInt32 = 29
    static let hidTypeField = CGEventField(rawValue: 110)
    static let motionField = CGEventField(rawValue: 123)
    static let progressField = CGEventField(rawValue: 124)
    static let phaseField = CGEventField(rawValue: 132)
    /// kIOHIDEventTypeDockSwipe
    static let dockSwipeHIDType: Int64 = 23
    /// Left or right, as opposed to up (Mission Control) or down (App Exposé).
    static let horizontalMotion: Int64 = 1

    /// The swipe is the one that switches Spaces.
    static func isSpaceSwipe(type: UInt32, hidType: Int64, motion: Int64) -> Bool {
        type == dockControlType && hidType == dockSwipeHIDType && motion == horizontalMotion
    }

    /// Gesture phases: 1 began, 2 changed, 4 ended, 8 cancelled.
    static func phase(fromRaw raw: Int64) -> Phase? {
        switch raw {
        case 1: .began
        case 2: .changed
        case 4, 8: .ended
        default: nil
        }
    }
}

/// Watches for the Space-switching swipe, so the notch can move with it (spec N-10). A
/// listen-only event tap: it never changes or blocks the gesture.
@MainActor
final class SpaceSwipeMonitor {
    private let onPhase: (SpaceSwipe.Phase) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var isSwiping = false
    /// Gesture events written to the log for troubleshooting, a few per launch.
    private var logged = 0

    init(onPhase: @escaping (SpaceSwipe.Phase) -> Void) {
        self.onPhase = onPhase
    }

    func start() {
        guard tap == nil else { return }
        let mask = CGEventMask(1) << SpaceSwipe.dockControlType | CGEventMask(1) << SpaceSwipe.gestureType
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<SpaceSwipeMonitor>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.handle(type: type, event: event) }
            return Unmanaged.passUnretained(event)
        }
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            DiagnosticsLog.append("spaces", "swipe tap not created (Accessibility: \(AXIsProcessTrusted()))")
            return
        }
        let runLoopSource = CFMachPortCreateRunLoopSource(nil, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        tap = created
        source = runLoopSource
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let hidType = event.getIntegerValueField(SpaceSwipe.hidTypeField)
        let motion = event.getIntegerValueField(SpaceSwipe.motionField)
        let rawPhase = event.getIntegerValueField(SpaceSwipe.phaseField)
        log(type: type, hidType: hidType, motion: motion, rawPhase: rawPhase, event: event)
        guard SpaceSwipe.isSpaceSwipe(type: type.rawValue, hidType: hidType, motion: motion),
              let phase = SpaceSwipe.phase(fromRaw: rawPhase)
        else { return }
        switch phase {
        case .began:
            guard !isSwiping else { return }
            isSwiping = true
            onPhase(.began)
        case .changed:
            // A swipe whose start was missed still counts.
            if !isSwiping {
                isSwiping = true
                onPhase(.began)
            }
        case .ended:
            guard isSwiping else { return }
            isSwiping = false
            onPhase(.ended)
        }
    }

    /// The fields of the first dock gestures, so the detection can be checked (no content).
    private func log(type: CGEventType, hidType: Int64, motion: Int64, rawPhase: Int64, event: CGEvent) {
        guard type.rawValue == SpaceSwipe.dockControlType, logged < 40 else { return }
        logged += 1
        let progress = event.getDoubleValueField(SpaceSwipe.progressField)
        DiagnosticsLog.append(
            "spaces",
            "dock event: hid=\(hidType) motion=\(motion) phase=\(rawPhase) progress=\(String(format: "%.2f", progress))"
        )
    }
}
