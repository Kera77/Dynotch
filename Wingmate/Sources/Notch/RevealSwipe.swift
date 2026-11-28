import CoreGraphics
import Foundation

/// A swipe down (two fingers on a trackpad, a flick on a Magic Mouse, a wheel turn) or up over
/// the closed notch's row, once per gesture (spec DS-2). Pure, so it can be tested.
struct RevealSwipe {
    enum Direction: Equatable {
        /// Down: open the drop-down.
        case open
        /// Up: close it.
        case close
    }

    static let threshold: CGFloat = 20
    static let dominance: CGFloat = 2
    /// Events without a gesture phase (a wheel) further apart than this start a new gesture.
    static let wheelGap: TimeInterval = 0.3

    private var down: CGFloat = 0
    private var across: CGFloat = 0
    private var fired = false
    private var lastTime: TimeInterval = -.infinity

    /// - Parameters:
    ///   - fingerDown: positive = fingers (or the wheel) moved down, whatever "natural scrolling" says.
    ///   - began: the event starts a gesture; nil for events without a phase.
    mutating func handle(fingerDown: CGFloat, across deltaX: CGFloat, began: Bool?, isMomentum: Bool, time: TimeInterval) -> Direction? {
        guard !isMomentum else { return nil }
        if began == true || (began == nil && time - lastTime > Self.wheelGap) {
            down = 0
            across = 0
            fired = false
        }
        lastTime = time
        down += fingerDown
        across += abs(deltaX)
        guard !fired, abs(down) >= Self.threshold, abs(down) >= across * Self.dominance else { return nil }
        fired = true
        return down > 0 ? .open : .close
    }
}

/// The swipe being gathered over a notification under the notch (spec DS-4).
@MainActor
final class DropdownReveal {
    var swipe = RevealSwipe()
}
