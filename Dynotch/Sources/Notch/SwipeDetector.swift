import CoreGraphics
import Foundation

/// Turns a stream of trackpad scroll events into single "next/previous" swipes (spec S-1…S-4).
struct SwipeDetector {
    enum Phase {
        case began
        case changed
        case ended
        /// Event without a gesture phase (e.g. a mouse wheel): ignored.
        case none
    }

    var threshold: CGFloat = 30
    /// Horizontal movement must dominate vertical movement by this factor.
    var dominance: CGFloat = 1.5

    private(set) var accumulatedX: CGFloat = 0
    private(set) var accumulatedY: CGFloat = 0
    private var hasFired = false

    init(threshold: CGFloat = 30) {
        self.threshold = threshold
    }

    /// True while the current gesture is mostly horizontal; such events should not reach the content.
    var isHorizontalGesture: Bool {
        accumulatedX != 0 && abs(accumulatedX) > abs(accumulatedY)
    }

    /// - Parameters:
    ///   - fingerDeltaX: horizontal finger movement, positive = fingers moved right
    ///     (independent of the "natural scrolling" setting).
    /// - Returns: a direction at most once per gesture. Fingers left = next, right = previous.
    mutating func handle(phase: Phase, isMomentum: Bool, fingerDeltaX: CGFloat, deltaY: CGFloat) -> NavigationDirection? {
        guard !isMomentum else { return nil }

        switch phase {
        case .none:
            return nil
        case .began:
            accumulatedX = 0
            accumulatedY = 0
            hasFired = false
        case .changed:
            break
        case .ended:
            return nil
        }

        accumulatedX += fingerDeltaX
        accumulatedY += deltaY

        guard !hasFired,
              abs(accumulatedX) >= threshold,
              abs(accumulatedX) > abs(accumulatedY) * dominance
        else { return nil }

        hasFired = true
        return accumulatedX < 0 ? .next : .previous
    }
}

/// Turns horizontal scrolling over the calendar's day strip into day steps: one day per
/// `stepWidth` points of finger movement, including the momentum after a flick.
struct DayStepper {
    var stepWidth: CGFloat = 60
    /// How much the momentum after a flick counts (spec M-14).
    var momentumScale: CGFloat = 1

    init(stepWidth: CGFloat = 60, momentumScale: CGFloat = 1) {
        self.stepWidth = stepWidth
        self.momentumScale = momentumScale
    }

    private var remainder: CGFloat = 0
    private var accumulatedX: CGFloat = 0
    private var accumulatedY: CGFloat = 0

    /// True while the current gesture is mostly horizontal.
    var isHorizontal: Bool {
        accumulatedX != 0 && abs(accumulatedX) >= abs(accumulatedY)
    }

    /// - Returns: days to move; fingers moving left go forward in time.
    mutating func handle(phase: SwipeDetector.Phase, isMomentum: Bool, fingerDeltaX: CGFloat, deltaY: CGFloat) -> Int {
        if phase == .began {
            remainder = 0
            accumulatedX = 0
            accumulatedY = 0
        }
        guard phase != .none || isMomentum else { return 0 }
        accumulatedX += abs(fingerDeltaX)
        accumulatedY += abs(deltaY)
        guard isHorizontal else { return 0 }

        remainder -= fingerDeltaX * (isMomentum ? momentumScale : 1)
        let steps = Int((remainder / stepWidth).rounded(.towardZero))
        remainder -= CGFloat(steps) * stepWidth
        return steps
    }
}

/// A two-finger swipe up: fires once per gesture after `threshold` points (spec K-8f).
struct VerticalSwipe {
    var threshold: CGFloat = 30

    private var accumulatedUp: CGFloat = 0
    private var accumulatedX: CGFloat = 0
    private var hasFired = false

    /// - Parameter fingerUp: vertical finger movement, positive = up.
    mutating func handle(phase: SwipeDetector.Phase, fingerUp: CGFloat, deltaX: CGFloat) -> Bool {
        switch phase {
        case .none, .ended:
            return false
        case .began:
            accumulatedUp = 0
            accumulatedX = 0
            hasFired = false
        case .changed:
            break
        }
        accumulatedUp += fingerUp
        accumulatedX += abs(deltaX)
        guard !hasFired, accumulatedUp >= threshold, accumulatedUp > accumulatedX else { return false }
        hasFired = true
        return true
    }
}

/// Gathers steps and lets them through one at a time, never several at once: a strong flick
/// walks through the modules or days faster, not jumps to the end (spec M-17, K-17).
struct StepQueue {
    /// One waiting step goes every 0.15 s, many every 0.06 s.
    static let slowest: TimeInterval = 0.15
    static let fastest: TimeInterval = 0.06

    /// The most steps one gesture can have waiting.
    var maxPending = 5
    private(set) var pending = 0
    private var last = Date.distantPast

    init(maxPending: Int = 5) {
        self.maxPending = maxPending
    }

    mutating func reset() {
        pending = 0
    }

    /// Adds a gesture's steps; turning back drops the ones still waiting the other way.
    mutating func add(_ steps: Int) {
        guard steps != 0 else { return }
        if pending != 0, (pending > 0) != (steps > 0) { pending = 0 }
        pending = max(-maxPending, min(maxPending, pending + steps))
    }

    /// The wait before the next step: shorter while more are waiting.
    nonisolated static func interval(pending: Int) -> TimeInterval {
        max(fastest, slowest - 0.03 * Double(abs(pending) - 1))
    }

    /// One step (+1 or -1) when it is due, 0 otherwise.
    mutating func next(now: Date = Date()) -> Int {
        guard pending != 0, now.timeIntervalSince(last) >= Self.interval(pending: pending) else { return 0 }
        last = now
        let step = pending > 0 ? 1 : -1
        pending -= step
        return step
    }
}
