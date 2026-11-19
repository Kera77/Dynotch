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
/// thread on its own timer.
@MainActor
final class WindowListMonitor {
    static let shared = WindowListMonitor()

    struct Token: Hashable {
        fileprivate let id: Int
    }

    private struct Subscriber {
        var interval: TimeInterval
        var lastSent: Date
        let handler: @MainActor ([ListedWindow]) -> Void
    }

    private var subscribers: [Int: Subscriber] = [:]
    private var nextID = 0
    private var timer: Timer?
    private var tick: TimeInterval = 0
    private var isReading = false
    /// The last list read; empty before the first.
    private(set) var latest: [ListedWindow] = []

    /// `handler` gets the list about every `interval` seconds, the first one at once.
    @discardableResult
    func subscribe(every interval: TimeInterval, _ handler: @escaping @MainActor ([ListedWindow]) -> Void) -> Token {
        nextID += 1
        subscribers[nextID] = Subscriber(interval: interval, lastSent: .distantPast, handler: handler)
        reschedule()
        read()
        return Token(id: nextID)
    }

    func setInterval(_ interval: TimeInterval, for token: Token) {
        guard let current = subscribers[token.id], current.interval != interval else { return }
        subscribers[token.id]?.interval = interval
        reschedule()
    }

    func unsubscribe(_ token: Token) {
        subscribers[token.id] = nil
        reschedule()
    }

    private func reschedule() {
        let wanted = subscribers.values.map(\.interval).min() ?? 0
        guard wanted != tick else { return }
        tick = wanted
        timer?.invalidate()
        timer = nil
        guard wanted > 0 else { return }
        timer = RepeatingTimer.start(every: wanted) { [weak self] in self?.read() }
    }

    private func isDue(_ subscriber: Subscriber, now: Date) -> Bool {
        now.timeIntervalSince(subscriber.lastSent) >= subscriber.interval - tick / 2
    }

    private func read() {
        let now = Date()
        guard !isReading, subscribers.values.contains(where: { isDue($0, now: now) }) else { return }
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
        for (id, subscriber) in subscribers where isDue(subscriber, now: now) {
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
