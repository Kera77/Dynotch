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
    /// Undocumented fields; nil if this macOS does not know them.
    static let hidTypeField: CGEventField? = CGEventField(rawValue: 110)
    static let motionField: CGEventField? = CGEventField(rawValue: 123)
    static let progressField: CGEventField? = CGEventField(rawValue: 124)
    static let phaseField: CGEventField? = CGEventField(rawValue: 132)
    /// kIOHIDEventTypeDockSwipe
    static let dockSwipeHIDType: Int64 = 23
    /// Left or right, as opposed to up (Mission Control) or down (App Exposé).
    static let horizontalMotion: Int64 = 1
    static let verticalMotion: Int64 = 2

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
    /// The up/down swipe (Mission Control, App Exposé): its progress, negative upwards, and
    /// whether it ended (spec N-19b).
    var onVerticalSwipe: (Double, Bool) -> Void = { _, _ in }
    /// A two-finger pinch, whichever app is active (spec HT-40).
    var onMagnify: (NSEvent) -> Void = { _ in }
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
        guard !forwardsMagnify(event), let hidField = SpaceSwipe.hidTypeField, let motionField = SpaceSwipe.motionField,
              let phaseField = SpaceSwipe.phaseField
        else { return }
        let hidType = event.getIntegerValueField(hidField)
        let motion = event.getIntegerValueField(motionField)
        let rawPhase = event.getIntegerValueField(phaseField)
        log(type: type, hidType: hidType, motion: motion, rawPhase: rawPhase, event: event)
        guard !forwardsVertical(type: type, hidType: hidType, motion: motion, rawPhase: rawPhase, event: event),
              SpaceSwipe.isSpaceSwipe(type: type.rawValue, hidType: hidType, motion: motion),
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

    /// A pinch goes to `onMagnify`: gesture events reach neither an app that is not active nor its
    /// global monitors (spec HT-40).
    private func forwardsMagnify(_ event: CGEvent) -> Bool {
        guard let gesture = NSEvent(cgEvent: event), gesture.type == .magnify else { return false }
        onMagnify(gesture)
        return true
    }

    /// An up/down dock swipe goes to `onVerticalSwipe`.
    private func forwardsVertical(type: CGEventType, hidType: Int64, motion: Int64, rawPhase: Int64, event: CGEvent) -> Bool {
        guard type.rawValue == SpaceSwipe.dockControlType, hidType == SpaceSwipe.dockSwipeHIDType, motion == SpaceSwipe.verticalMotion,
              let progressField = SpaceSwipe.progressField, let phase = SpaceSwipe.phase(fromRaw: rawPhase)
        else { return false }
        onVerticalSwipe(event.getDoubleValueField(progressField), phase == .ended)
        return true
    }

    /// The fields of the first dock gestures, so the detection can be checked (no content).
    private func log(type: CGEventType, hidType: Int64, motion: Int64, rawPhase: Int64, event: CGEvent) {
        guard type.rawValue == SpaceSwipe.dockControlType, logged < 40 else { return }
        logged += 1
        let progress = SpaceSwipe.progressField.map { event.getDoubleValueField($0) } ?? -1
        DiagnosticsLog.append(
            "spaces",
            "dock event: hid=\(hidType) motion=\(motion) phase=\(rawPhase) progress=\(String(format: "%.2f", progress))"
        )
    }
}
