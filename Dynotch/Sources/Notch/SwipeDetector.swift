import CoreGraphics

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
