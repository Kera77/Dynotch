import Foundation

/// A repeating background look (spec RF-8…RF-10): runs only while its feature wants it (the
/// `isActive` gate), stops while the displays sleep or the session is locked, and slows down in
/// Low Power Mode and on battery. While the gate is off, only a cheap check runs every
/// `Poller.idleCheck` seconds; coming back (gate on, wake, unlock) does one look at once.
@MainActor
final class Poller {
    enum Mode: Equatable {
        /// Not started, or everything paused: no timer at all.
        case stopped
        /// The gate is off: only the gate is checked now and then.
        case idle
        /// Looking every so many seconds.
        case running(TimeInterval)
    }

    /// How often a poller whose gate is off checks it again.
    nonisolated static let idleCheck: TimeInterval = 10

    /// Every poller pauses (displays asleep, session locked or inactive; spec RF-9).
    private(set) static var isPaused = false
    /// Background intervals are this many times longer (Low Power Mode, battery; spec RF-10).
    private(set) static var slowFactor: Double = 1
    private static let all = NSHashTable<Poller>.weakObjects()

    /// Seconds between looks at normal power.
    var interval: TimeInterval {
        didSet { if interval != oldValue { apply(resuming: false) } }
    }
    /// False for the fast looks that run only while something is on screen.
    var scalesWithPower: Bool {
        didSet { if scalesWithPower != oldValue { apply(resuming: false) } }
    }
    /// Runs when the gate turns off, e.g. to clear what the feature showed.
    var onInactive: (() -> Void)?

    private let tolerance: Double
    private let isActive: () -> Bool
    private let action: () -> Void
    private var timer: Timer?
    private var isStarted = false
    private(set) var mode: Mode = .stopped

    init(
        every interval: TimeInterval, tolerance: Double = 0.2, scalesWithPower: Bool = true,
        isActive: @escaping () -> Bool = { true }, action: @escaping () -> Void
    ) {
        self.interval = interval
        self.tolerance = tolerance
        self.scalesWithPower = scalesWithPower
        self.isActive = isActive
        self.action = action
    }

    /// Starts the ticks; `now` also looks at once when the gate is on.
    func start(now: Bool = false) {
        isStarted = true
        Self.all.add(self)
        apply(resuming: false)
        if now, mode != .idle, isActive() { action() }
    }

    func stop() {
        isStarted = false
        Self.all.remove(self)
        apply(resuming: false)
    }

    /// Like `Timer.invalidate()`, for the services that held a timer before.
    func invalidate() { stop() }

    /// A started poller, the way `RepeatingTimer.start` gave a timer.
    static func start(
        every interval: TimeInterval, tolerance: Double = 0.2, scalesWithPower: Bool = true,
        isActive: @escaping () -> Bool = { true }, action: @escaping () -> Void
    ) -> Poller {
        let poller = Poller(every: interval, tolerance: tolerance, scalesWithPower: scalesWithPower, isActive: isActive, action: action)
        poller.start()
        return poller
    }

    /// Checks the gate and the global state again; a poller that starts running looks at once.
    func reevaluate() {
        apply(resuming: true)
    }

    private func apply(resuming: Bool) {
        let active = isStarted && !Self.isPaused ? isActive() : false
        let next = Self.mode(
            started: isStarted, paused: Self.isPaused, active: active,
            interval: Self.scaled(interval, factor: Self.slowFactor, scales: scalesWithPower)
        )
        guard next != mode else { return }
        let previous = mode
        mode = next
        timer?.invalidate()
        timer = nil
        switch next {
        case .stopped:
            break
        case .idle:
            timer = RepeatingTimer.start(every: Self.idleCheck, tolerance: 0.5) { [weak self] in self?.reevaluate() }
            if case .running = previous { onInactive?() }
        case .running(let seconds):
            timer = RepeatingTimer.start(every: seconds, tolerance: tolerance) { [weak self] in self?.fire() }
            if resuming, previous == .idle || previous == .stopped { action() }
        }
    }

    private func fire() {
        guard isActive() else { return reevaluate() }
        action()
    }

    /// What a poller does, from its state (pure, for the tests).
    nonisolated static func mode(started: Bool, paused: Bool, active: Bool, interval: TimeInterval) -> Mode {
        guard started, !paused, interval > 0 else { return .stopped }
        return active ? .running(interval) : .idle
    }

    nonisolated static func scaled(_ interval: TimeInterval, factor: Double, scales: Bool) -> TimeInterval {
        scales ? interval * max(factor, 1) : interval
    }

    // MARK: - All pollers

    /// Every poller (and the window list) checks its gate again, e.g. after a setting changed.
    static func reevaluateAll() {
        for poller in all.allObjects { poller.reevaluate() }
        WindowListMonitor.shared.reevaluate()
    }

    static func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        reevaluateAll()
    }

    static func setSlowFactor(_ factor: Double) {
        guard factor != slowFactor else { return }
        slowFactor = factor
        reevaluateAll()
    }
}
