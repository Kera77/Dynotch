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

/// Gathers steps and lets them through together at most every `interval`, so a long swipe
/// switches smoothly instead of restarting the animation on every event (spec M-14).
struct StepThrottle {
    var interval: TimeInterval = 0.1
    private var pending = 0
    private var last = Date.distantPast

    mutating func reset() {
        pending = 0
    }

    /// The steps to take now, 0 while waiting.
    mutating func add(_ steps: Int, now: Date = Date()) -> Int {
        pending += steps
        guard pending != 0, now.timeIntervalSince(last) >= interval else { return 0 }
        defer { pending = 0 }
        last = now
        return pending
    }
}
