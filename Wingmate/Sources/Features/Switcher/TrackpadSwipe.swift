import AppKit

/// The trackpad's raw touches (the private MultitouchSupport framework, looked up at run time):
/// a horizontal swipe with the chosen number of fingers opens the switcher, moving them steps
/// the choice, lifting them switches (spec AS-11). A swipe up with its own number of fingers
/// opens the module switcher the same way (spec QS-2).
final class TrackpadSwipe: @unchecked Sendable {
    /// One finger as the framework reports it (layout as used by open-source tools).
    private struct Touch {
        var frame: Int32
        var timestamp: Double
        var identifier: Int32
        var state: Int32
        var fingerID: Int32
        var handID: Int32
        var normalizedX: Float
        var normalizedY: Float
        var velocityX: Float
        var velocityY: Float
        var size: Float
        var zero1: Int32
        var angle: Float
        var majorAxis: Float
        var minorAxis: Float
        var absoluteX: Float
        var absoluteY: Float
        var absoluteVelocityX: Float
        var absoluteVelocityY: Float
        var zero2: Int32
        var zero3: Int32
        var density: Float
    }

    private typealias Callback = @convention(c) (Int32, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    private typealias Register = @convention(c) (UnsafeMutableRawPointer, Callback) -> Void
    private typealias Start = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void

    /// Which gesture started: sideways for the window switcher, up for the module switcher.
    enum Mode: Sendable { case sideways, upward }

    enum Event: Sendable {
        case began(Mode)
        /// Horizontal travel since the start, in trackpad widths (−1…1).
        case moved(Double)
        case ended(cancelled: Bool)
    }

    /// Fingers that make the gesture; 0 turns it off. Read on the touch thread.
    nonisolated(unsafe) static var fingers = 3
    /// Fingers of the swipe up (spec QS-1); 0 turns it off.
    nonisolated(unsafe) static var upFingers = 0
    nonisolated(unsafe) private static var handler: (@Sendable (Event) -> Void)?
    nonisolated(unsafe) private static var startX: Float?
    nonisolated(unsafe) private static var startY: Float = 0
    nonisolated(unsafe) private static var mode: Mode?
    /// Where a swipe up began, and the highest point since: moving down from it cancels (spec QS-8).
    nonisolated(unsafe) private static var upOriginX: Float = 0
    nonisolated(unsafe) private static var peakY: Float = 0
    nonisolated(unsafe) private static var lastCount = 0
    /// Cancelled by a vertical swipe: nothing more until the fingers lift.
    nonisolated(unsafe) private static var isSpent = false
    /// Most fingers down since the trackpad was last empty: a 4-finger swipe passes through 3.
    nonisolated(unsafe) private static var mostFingers = 0
    /// Frames with exactly the wanted fingers, so fingers still landing do not start it.
    nonisolated(unsafe) private static var steadyFrames = 0
    nonisolated(unsafe) private static var lastX: Float = 0
    nonisolated(unsafe) private static var lastY: Float = 0
    nonisolated(unsafe) private static var started = false

    /// Minimum horizontal travel before the switcher opens, so a resting hand does nothing (spec AS-21).
    private static let openDistance: Float = 0.06
    /// Vertical travel (up or down) that cancels an open switcher at once (spec AS-11c), only
    /// when it is clearly more than the horizontal one: a hand swiping sideways drifts too (spec AS-21).
    private static let cancelDistance: Float = 0.25
    private static let cancelDominance: Float = 1.5
    /// Touch states of a finger that is really on the trackpad: "make touch" (3) and "touching" (4);
    /// 5 is lifting, 1-2 and 6-7 hovering or lingering.
    /// Hovering, lifting and lingering contacts jump about and must not count (spec AS-21).
    private static let downStates: Set<Int32> = [3, 4]
    /// Frames (~8 ms each) the fingers must stay exactly the wanted number before it opens.
    private static let steadyNeeded = 6

    /// Starts listening once; `handler` gets the events on the main queue.
    static func start(_ handler: @escaping @Sendable (Event) -> Void) {
        self.handler = handler
        guard !started else { return }
        started = true
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let library = dlopen(path, RTLD_LAZY),
              let createPointer = dlsym(library, "MTDeviceCreateList"),
              let registerPointer = dlsym(library, "MTRegisterContactFrameCallback"),
              let startPointer = dlsym(library, "MTDeviceStart")
        else {
            DiagnosticsLog.append("spaces", "trackpad touches not available")
            return
        }
        let create = unsafeBitCast(createPointer, to: CreateList.self)
        let register = unsafeBitCast(registerPointer, to: Register.self)
        let begin = unsafeBitCast(startPointer, to: Start.self)
        guard let devices = create()?.takeRetainedValue() as? [AnyObject] else { return }
        for device in devices {
            let pointer = Unmanaged.passUnretained(device).toOpaque()
            register(pointer, frameCallback)
            begin(pointer, 0)
        }
    }

    private static let frameCallback: Callback = { _, data, count, _, _ in
        TrackpadSwipe.frame(data: data, count: Int(count))
        return 0
    }

    private static func frame(data: UnsafeMutableRawPointer?, count: Int) {
        let sideways = fingers
        let upward = upFingers
        guard sideways > 0 || upward > 0, let data else { return }
        let all = data.bindMemory(to: Touch.self, capacity: max(count, 1))
        let touches = (0..<count).map { all[$0] }.filter { downStates.contains($0.state) }
        let count = touches.count
        let wanted = wantedFingers(count: count, sideways: sideways, upward: upward)
        // A finger more or less: the average jumps, so the gesture starts over from here.
        if count != lastCount, mode == nil {
            startX = nil
            steadyFrames = 0
        }
        lastCount = count
        mostFingers = max(mostFingers, count)
        if count > wanted || mostFingers > wanted {
            // More fingers than the switcher's: a Space swipe or the like, not ours (spec AS-11d).
            if mode != nil { send(.ended(cancelled: true)) }
            mode = nil
            isSpent = true
            lifted(count: count, wanted: wanted)
        } else if count == wanted {
            steadyFrames += 1
            var sumX: Float = 0
            var sumY: Float = 0
            for touch in touches {
                sumX += touch.normalizedX
                sumY += touch.normalizedY
            }
            moved(x: sumX / Float(count), y: sumY / Float(count), count: count)
        } else {
            // Fingers lifted: switch.
            if mode != nil { send(.ended(cancelled: false)) }
            mode = nil
            lifted(count: count, wanted: wanted)
        }
    }

    /// The fingers the gesture under way needs, or the count down if a gesture takes that many.
    private static func wantedFingers(count: Int, sideways: Int, upward: Int) -> Int {
        switch mode {
        case .sideways: return sideways
        case .upward: return upward
        case nil: return count > 0 && (count == sideways || count == upward) ? count : max(sideways, upward)
        }
    }

    /// The fingers' average position, with exactly the wanted number down.
    private static func moved(x: Float, y: Float, count: Int) {
        lastX = x
        lastY = y
        guard let origin = startX else {
            startX = x
            startY = y
            return
        }
        let travel = x - origin
        let rise = y - startY
        switch mode {
        case .sideways:
            if abs(rise) >= cancelDistance, abs(rise) > abs(travel) * cancelDominance {
                // Swiped up or down: cancel now, without switching (spec AS-11c).
                cancel()
                return
            }
            send(.moved(Double(travel)))
        case .upward:
            peakY = max(peakY, y)
            if peakY - y >= cancelDistance {
                // Back down: cancel, no module opens (spec QS-8).
                cancel()
                return
            }
            send(.moved(Double(x - upOriginX)))
        case nil:
            guard !isSpent, steadyFrames >= steadyNeeded else { return }
            if count == fingers, abs(travel) >= openDistance, abs(travel) > abs(rise) {
                mode = .sideways
                send(.began(.sideways))
                send(.moved(Double(travel)))
            } else if count == upFingers, rise >= openDistance, rise > abs(travel) {
                // A swipe up: the module switcher (spec QS-2); sideways steps count from here.
                mode = .upward
                upOriginX = x
                peakY = y
                send(.began(.upward))
            }
        }
    }

    private static func cancel() {
        mode = nil
        isSpent = true
        send(.ended(cancelled: true))
    }

    private static func lifted(count: Int, wanted: Int) {
        startX = nil
        steadyFrames = 0
        if count < wanted { reset() }
    }

    private static func reset() {
        isSpent = false
        mostFingers = 0
    }

    private static func send(_ event: Event) {
        guard let handler else { return }
        DispatchQueue.main.async { handler(event) }
    }
}
