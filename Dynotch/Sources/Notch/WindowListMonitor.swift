import AppKit

/// One on-screen window as the window server lists it: owner, title, layer and frame (no content).
struct ListedWindow: Hashable, Sendable {
    let id: CGWindowID
    let pid: pid_t
    let owner: String
    let name: String
    let layer: Int
    /// In window-server coordinates (origin top-left of the primary display).
    let frame: CGRect

    init(id: CGWindowID = 0, pid: pid_t = 0, owner: String, name: String = "", layer: Int = 0, frame: CGRect = .zero) {
        self.id = id
        self.pid = pid
        self.owner = owner
        self.name = name
        self.layer = layer
        self.frame = frame
    }

    init?(info: [String: Any]) {
        guard let id = info[kCGWindowNumber as String] as? CGWindowID,
              let pid = info[kCGWindowOwnerPID as String] as? pid_t
        else { return nil }
        let bounds = (info[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0 as CFDictionary) }
        self.init(
            id: id, pid: pid, owner: info[kCGWindowOwnerName as String] as? String ?? "",
            name: info[kCGWindowName as String] as? String ?? "",
            layer: info[kCGWindowLayer as String] as? Int ?? 0, frame: bounds ?? .zero
        )
    }
}

/// Reads the on-screen window list once per tick, in the background, for every watcher that needs
/// it (full screen, Mission Control, screen sharing, calls) instead of each asking on the main
/// thread on its own timer. A watcher whose gate is off is left out (spec RF-8); everything stops
/// while `Poller` is paused and slows down with it (spec RF-9, RF-10).
@MainActor
final class WindowListMonitor {
    static let shared = WindowListMonitor()

    struct Token: Hashable {
        fileprivate let id: Int
    }

    private struct Subscriber {
        var interval: TimeInterval
        var scalesWithPower: Bool
        var lastSent: Date
        let isActive: @MainActor () -> Bool
        let handler: @MainActor ([ListedWindow]) -> Void

        func effectiveInterval(factor: Double) -> TimeInterval {
            Poller.scaled(interval, factor: factor, scales: scalesWithPower)
        }
    }

    private var subscribers: [Int: Subscriber] = [:]
    private var nextID = 0
    private var timer: Timer?
    private var tick: TimeInterval = 0
    private var isReading = false
    private var wasPaused = false
    /// The last list read; empty before the first.
    private(set) var latest: [ListedWindow] = []

    /// `handler` gets the list about every `interval` seconds, the first one at once, while
    /// `isActive` says so.
    @discardableResult
    func subscribe(
        every interval: TimeInterval, scalesWithPower: Bool = true, isActive: @escaping @MainActor () -> Bool = { true },
        _ handler: @escaping @MainActor ([ListedWindow]) -> Void
    ) -> Token {
        nextID += 1
        subscribers[nextID] = Subscriber(
            interval: interval, scalesWithPower: scalesWithPower, lastSent: .distantPast, isActive: isActive, handler: handler
        )
        reschedule()
        read()
        return Token(id: nextID)
    }

    func setInterval(_ interval: TimeInterval, scalesWithPower: Bool = true, for token: Token) {
        guard let current = subscribers[token.id],
              current.interval != interval || current.scalesWithPower != scalesWithPower
        else { return }
        subscribers[token.id]?.interval = interval
        subscribers[token.id]?.scalesWithPower = scalesWithPower
        reschedule()
    }

    func unsubscribe(_ token: Token) {
        subscribers[token.id] = nil
        reschedule()
    }

    /// Gates, pause and power checked again; after a pause, one look at once.
    func reevaluate() {
        let resumed = wasPaused && !Poller.isPaused
        wasPaused = Poller.isPaused
        reschedule()
        if resumed { read() }
    }

    private var activeSubscribers: [Int: Subscriber] {
        subscribers.filter { $0.value.isActive() }
    }

    private func reschedule() {
        let wanted = Poller.isPaused ? 0 : Self.tick(
            for: activeSubscribers.values.map { $0.effectiveInterval(factor: Poller.slowFactor) },
            hasSubscribers: !subscribers.isEmpty
        )
        guard wanted != tick else { return }
        tick = wanted
        timer?.invalidate()
        timer = nil
        guard wanted > 0 else { return }
        timer = RepeatingTimer.start(every: wanted) { [weak self] in self?.timerFired() }
    }

    /// The shortest interval wanted; only a gate check now and then while every gate is off.
    nonisolated static func tick(for intervals: [TimeInterval], hasSubscribers: Bool) -> TimeInterval {
        intervals.min() ?? (hasSubscribers ? Poller.idleCheck : 0)
    }

    private func timerFired() {
        reschedule()
        read()
    }

    private func isDue(_ subscriber: Subscriber, now: Date) -> Bool {
        now.timeIntervalSince(subscriber.lastSent) >= subscriber.effectiveInterval(factor: Poller.slowFactor) - tick / 2
    }

    private func read() {
        let now = Date()
        guard !isReading, !Poller.isPaused, activeSubscribers.values.contains(where: { isDue($0, now: now) }) else { return }
        isReading = true
        Task { [weak self] in
            let windows = await Task.detached { WindowListMonitor.onScreenWindows() }.value
            self?.deliver(windows)
        }
    }

    private func deliver(_ windows: [ListedWindow]) {
        isReading = false
        latest = windows
        let now = Date()
        for (id, subscriber) in activeSubscribers where isDue(subscriber, now: now) {
            subscribers[id]?.lastSent = now
            subscriber.handler(windows)
        }
    }

    /// Front to back.
    nonisolated static func onScreenWindows() -> [ListedWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return info.compactMap(ListedWindow.init(info:))
    }
}
