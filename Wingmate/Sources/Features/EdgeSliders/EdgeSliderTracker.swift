import CoreGraphics
import Foundation

/// Turns the trackpad's touch frames into edge-slider steps (spec ES-1…ES-3). Pure: positions are
/// the trackpad's normalized 0…1 coordinates, y = 1 at the far (top) edge.
struct EdgeSliderTracker {
    enum Output: Equatable {
        /// A slide started on this edge.
        case began(EdgeZone)
        /// Steps from where the slide started (positive = louder, brighter).
        case moved(EdgeZone, steps: Int)
        case ended(EdgeZone)
    }

    /// The edges' depth (spec ES-2).
    static let edge: CGFloat = 0.08
    /// The corners belong to no edge (spec ES-1).
    static let corner: CGFloat = 0.12
    /// Travel along the edge before the slider takes over (spec ES-2).
    static let activation: CGFloat = 0.03
    /// The movement along the edge must be this many times the movement across it.
    static let dominance: CGFloat = 2

    /// The travel of one step: 16 over 60% of the trackpad, 100 over 80% (spec ES-3).
    static func stepLength(steps: Int, zone: EdgeZone) -> CGFloat {
        let span: CGFloat = steps <= 16 ? 0.6 : 0.8
        return span / CGFloat(steps)
    }

    var enabled: Set<EdgeZone> = Set(EdgeZone.allCases)
    var steps = 16

    private enum State {
        case idle
        /// A finger came down on an edge; not yet a slide.
        case candidate(EdgeZone, start: CGPoint)
        case active(EdgeZone, anchor: CGFloat, emitted: Int)
        /// A touch that is not a slide, until every finger is up.
        case ignored
    }

    private var state = State.idle

    static func zone(at point: CGPoint) -> EdgeZone? {
        let inSides = point.y > corner && point.y < 1 - corner
        if point.x < edge, inSides { return .left }
        if point.x > 1 - edge, inSides { return .right }
        if point.y > 1 - edge, point.x > corner, point.x < 1 - corner { return .top }
        return nil
    }

    /// The position along the edge that grows the level: up the sides, right along the top.
    static func along(_ point: CGPoint, in zone: EdgeZone) -> CGFloat {
        zone == .top ? point.x : point.y
    }

    static func across(_ point: CGPoint, in zone: EdgeZone) -> CGFloat {
        zone == .top ? point.y : point.x
    }

    /// - Parameter touches: the fingers on the trackpad now.
    mutating func handle(touches: [CGPoint]) -> Output? {
        switch state {
        case .idle:
            begin(touches)
            return nil
        case .ignored:
            if touches.isEmpty { state = .idle }
            return nil
        case .candidate(let zone, let start):
            return decide(touches, zone: zone, start: start)
        case .active(let zone, let anchor, let emitted):
            return slide(touches, zone: zone, anchor: anchor, emitted: emitted)
        }
    }

    private mutating func begin(_ touches: [CGPoint]) {
        guard touches.count == 1, let zone = Self.zone(at: touches[0]), enabled.contains(zone) else {
            if !touches.isEmpty { state = .ignored }
            return
        }
        state = .candidate(zone, start: touches[0])
    }

    /// A finger on an edge: a slide along it, or an ordinary pointer move.
    private mutating func decide(_ touches: [CGPoint], zone: EdgeZone, start: CGPoint) -> Output? {
        guard touches.count == 1 else {
            state = touches.isEmpty ? .idle : .ignored
            return nil
        }
        let point = touches[0]
        let along = abs(Self.along(point, in: zone) - Self.along(start, in: zone))
        let across = abs(Self.across(point, in: zone) - Self.across(start, in: zone))
        if along >= Self.activation, along >= across * Self.dominance {
            state = .active(zone, anchor: Self.along(point, in: zone), emitted: 0)
            return .began(zone)
        }
        if along >= Self.activation || across >= Self.activation { state = .ignored }
        return nil
    }

    private mutating func slide(_ touches: [CGPoint], zone: EdgeZone, anchor: CGFloat, emitted: Int) -> Output? {
        // A second finger, or lifting it, ends the slide (spec ES-2).
        guard touches.count == 1 else {
            state = touches.isEmpty ? .idle : .ignored
            return .ended(zone)
        }
        let travel = Self.along(touches[0], in: zone) - anchor
        let count = Int((travel / Self.stepLength(steps: steps, zone: zone)).rounded(.towardZero))
        guard count != emitted else { return nil }
        state = .active(zone, anchor: anchor, emitted: count)
        return .moved(zone, steps: count)
    }

    /// The level after `steps` from `start`, on the grid of `count` steps.
    static func level(from start: Double, steps: Int, count: Int) -> Double {
        let base = (start * Double(count)).rounded()
        return min(max((base + Double(steps)) / Double(count), 0), 1)
    }
}
