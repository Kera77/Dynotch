import AppKit
import Observation

/// Spencer's window layouts through its own command-line tool, and the switch to the layout
/// that belongs to the connected displays (spec SL-1…SL-6).
@MainActor
@Observable
final class SpencerService {
    static let shared = SpencerService()

    nonisolated static let appPath = "/Applications/Spencer.app"
    nonisolated static let toolPath = appPath + "/Contents/MacOS/SpencerCLI"
    /// How long the notice counts down before the switch (spec SL-4).
    static let countdown: TimeInterval = 10
    /// Displays come one after the other: the setup is read once they rest (spec SL-3).
    static let settle: TimeInterval = 3
    /// Launching the layout's apps can take a while.
    static let restoreTimeout: TimeInterval = 120

    private(set) var isInstalled = false
    private(set) var layouts: [String] = []
    private(set) var failure: String?
    private(set) var setup: DisplaySetup?
    /// Display setup key → layout name (spec SL-2, SL-5).
    private(set) var assignments: [String: String]
    /// The displays each layout was made for, from Spencer's database (spec SL-8).
    private(set) var layoutDisplays = SpencerLayoutDisplays()

    /// Switches by itself when the displays change (spec SL-5).
    var autoSwitch: Bool {
        didSet { defaults.set(autoSwitch, forKey: Self.autoSwitchKey) }
    }

    @ObservationIgnored private weak var notices: NoticeService?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var settling: Task<Void, Never>?
    @ObservationIgnored private var pending: (notice: StickyNotice, task: Task<Void, Never>)?
    @ObservationIgnored private let defaults: UserDefaults
    /// The last restore, so a display flicker right after it does not offer the same layout again.
    @ObservationIgnored private var lastRestore: Restore?

    private struct Restore {
        let layout: String
        let setupKey: String?
        let date: Date
    }

    nonisolated static let autoSwitchKey = "spencer.autoSwitch"
    nonisolated static let assignmentsKey = "spencer.assignments"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoSwitch = defaults.object(forKey: Self.autoSwitchKey) as? Bool ?? true
        assignments = defaults.dictionary(forKey: Self.assignmentsKey) as? [String: String] ?? [:]
    }

    /// The layout remembered for the displays connected now.
    var assigned: String? { setup.flatMap { assignments[$0.key] } }

    /// Greyed in the menu when its displays are not all connected (spec SL-7).
    func isAvailable(_ layout: String) -> Bool {
        layoutDisplays.isAvailable(layout, connected: setup?.uuids ?? [])
    }

    /// Notes the displays at launch, without switching (spec SL-3), and watches them from then on.
    func start(notices: NoticeService) {
        self.notices = notices
        isInstalled = FileManager.default.isExecutableFile(atPath: Self.toolPath)
        setup = DisplaySetup.current()
        guard observers.isEmpty else { return }
        observers = [
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.displaysChanged() }
            },
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.displaysChanged() }
            }
        ]
        if isInstalled { refresh() }
        DiagnosticsLog.append("spencer", "started: installed=\(isInstalled) displays=\(setup?.count ?? 0) auto=\(autoSwitch)")
    }

    // MARK: - Displays (spec SL-3, SL-4)

    private func displaysChanged() {
        settling?.cancel()
        settling = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.settle))
            guard !Task.isCancelled else { return }
            self?.evaluate()
        }
    }

    private func evaluate() {
        let now = DisplaySetup.current()
        guard now.key != setup?.key else { return }
        setup = now
        cancelPending()
        isInstalled = FileManager.default.isExecutableFile(atPath: Self.toolPath)
        Task {
            await loadLayoutDisplays()
            decide(for: now)
        }
    }

    /// The remembered layout, or else the one made for exactly these displays (spec SL-9).
    private func decide(for now: DisplaySetup) {
        guard setup?.key == now.key else { return }
        let assigned = assignments[now.key]
        let matched = assigned == nil ? layoutDisplays.matching(now.uuids, order: layouts) : nil
        let source = assigned != nil ? "assigned" : matched != nil ? "matched" : "none"
        DiagnosticsLog.append("spencer", "display setup changed: \(now.count) display(s), layout=\(source)")
        guard autoSwitch, isInstalled, let layout = assigned ?? matched else { return }
        if let last = lastRestore, last.layout == layout, last.setupKey == now.key, Date().timeIntervalSince(last.date) < 60 {
            DiagnosticsLog.append("spencer", "skipped: just restored")
            return
        }
        startCountdown(to: layout, setup: now)
    }

    private func loadLayoutDisplays() async {
        guard let found = await Task.detached(operation: { SpencerLayoutDisplays.load() }).value else { return }
        if found != layoutDisplays { layoutDisplays = found }
    }

    private func startCountdown(to layout: String, setup: DisplaySetup) {
        guard let notices else { return }
        let start = Date()
        let notice = StickyNotice(
            title: "Switching to \(layout)", detail: setup.title, date: start,
            symbol: SpencerMenu.symbol, sourceName: "Spencer",
            countdown: DateInterval(start: start, duration: Self.countdown)
        )
        notices.show(notice)
        DiagnosticsLog.append("spencer", "countdown started")
        let task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.countdown))
            guard !Task.isCancelled else { return }
            self?.finishCountdown(notice, layout: layout)
        }
        pending = (notice, task)
    }

    /// Cancel, the X or a swipe took the notice away: no switch (spec SL-4).
    private func finishCountdown(_ notice: StickyNotice, layout: String) {
        pending = nil
        guard let notices, notices.isShown(notice) else {
            DiagnosticsLog.append("spencer", "switch cancelled")
            return
        }
        notices.remove(notice)
        restore(layout)
    }

    private func cancelPending() {
        guard let pending else { return }
        pending.task.cancel()
        notices?.remove(pending.notice)
        self.pending = nil
    }

    // MARK: - Menu (spec SL-2)

    /// Restores the layout now and remembers it for the displays connected now.
    func choose(_ layout: String) {
        cancelPending()
        let now = DisplaySetup.current()
        setup = now
        assignments[now.key] = layout
        saveAssignments()
        restore(layout)
    }

    /// The layouts, read again each time the menu opens.
    func refresh() {
        isInstalled = FileManager.default.isExecutableFile(atPath: Self.toolPath)
        setup = DisplaySetup.current()
        guard isInstalled else { return }
        Task { await loadLayoutDisplays() }
        Task {
            guard let result = await execute(["--list"]) else { return }
            let found = Self.layouts(from: String(bytes: result.output, encoding: .utf8) ?? "")
            if found != layouts { layouts = found }
        }
    }

    func restore(_ layout: String) {
        lastRestore = Restore(layout: layout, setupKey: setup?.key, date: Date())
        Task {
            guard let result = await execute(["--restore", layout], timeout: Self.restoreTimeout) else { return }
            DiagnosticsLog.append("spencer", "restored: ok=\(result.succeeded)")
        }
    }

    // MARK: - Active workspace (spec SL-11)

    /// Restore Workspace: the most recently used layout again.
    func restoreActive() {
        Task {
            guard let result = await execute(["--restore-active"], timeout: Self.restoreTimeout) else { return }
            DiagnosticsLog.append("spencer", "restored the active layout: ok=\(result.succeeded)")
        }
    }

    /// Update Workspace › All Spaces, or › Current Space Only.
    func updateActive(currentSpaceOnly: Bool) {
        Task {
            guard let result = await execute([currentSpaceOnly ? "--update-active-desktop" : "--update-active"]) else { return }
            DiagnosticsLog.append("spencer", "updated the active layout (space only: \(currentSpaceOnly)): ok=\(result.succeeded)")
        }
    }

    func openSpencer() {
        NSWorkspace.shared.open(URL(fileURLWithPath: Self.appPath))
    }

    /// Runs the tool off the main thread; a failure is kept for the menu (spec SL-2).
    private func execute(_ arguments: [String], timeout: TimeInterval = 20) async -> ProcessRunner.Result? {
        let path = Self.toolPath
        let result = await Task.detached { ProcessRunner.run(path, arguments, timeout: timeout) }.value
        guard let result else {
            failure = "Spencer's command line tool did not start."
            DiagnosticsLog.append("spencer", "tool did not start")
            return nil
        }
        if result.succeeded {
            failure = nil
        } else {
            failure = result.timedOut ? "Spencer did not answer in time." : "Spencer could not do it."
            DiagnosticsLog.append("spencer", "\(arguments.first ?? "") failed: status=\(result.status) timedOut=\(result.timedOut)")
        }
        return result
    }

    private func saveAssignments() {
        defaults.set(assignments, forKey: Self.assignmentsKey)
    }

    /// The names under "Available layouts:" in `--list`'s output.
    nonisolated static func layouts(from output: String) -> [String] {
        let lines = output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let names = lines.drop { !$0.hasPrefix("Available layouts") }.dropFirst()
        return names.filter { !$0.isEmpty }
    }
}
