import AppKit
import Observation

/// The timers, the stopwatch and the pomodoro (spec TM-5…TM-17). Every time is kept as an end or
/// a start date and saved, so a restart or a sleep keeps it right (spec TM-6).
@MainActor
@Observable
final class ToolsService {
    static let shared = ToolsService()

    private(set) var timers: [CountdownTimer] = [] { didSet { save() } }
    private(set) var stopwatch = StopwatchState() { didSet { save() } }
    private(set) var pomodoro = PomodoroState() { didSet { save() } }
    private(set) var history = PomodoroHistory() { didSet { save() } }
    /// The last custom times, newest first (spec TM-9).
    private(set) var recent: [TimeInterval] = [] { didSet { save() } }

    static let maxTimers = 5

    @ObservationIgnored private var appSettings: AppSettings?
    @ObservationIgnored private var notices: NoticeService?
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var observer: ChangeObservation?
    @ObservationIgnored private var loading = false
    @ObservationIgnored private let alarm = ToolsAlarm()

    var settings: ToolsSettings { .shared }

    func start(settings appSettings: AppSettings, notices: NoticeService) {
        self.appSettings = appSettings
        self.notices = notices
        load()
        observer = observeChanges { [weak self] in
            _ = self?.timers
            _ = self?.pomodoro
            _ = self?.isRunning
        } onChange: { [weak self] in
            self?.updateTicker()
        }
        updateTicker()
        checkEnds(now: Date())
    }

    /// The module is on (spec G-4): nothing ticks and nothing shows beside the notch while it is off.
    var isRunning: Bool { appSettings?.isEnabled(.tools) == true }

    // MARK: - Timer (spec TM-7…TM-9)

    @discardableResult
    func startTimer(_ duration: TimeInterval, name: String = "", custom: Bool = false) -> Bool {
        guard duration > 0, timers.count < Self.maxTimers else { return false }
        timers.append(CountdownTimer(name: name.trimmingCharacters(in: .whitespaces), duration: duration, now: Date()))
        if custom, !settings.presets.contains(where: { TimeInterval($0 * 60) == duration }) {
            recent = Array(([duration] + recent.filter { $0 != duration }).prefix(3))
        }
        return true
    }

    func pauseOrResume(_ id: UUID) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        if timers[index].isPaused { timers[index].resume(at: Date()) } else { timers[index].pause(at: Date()) }
    }

    func addMinute(_ id: UUID) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        timers[index].addMinute()
    }

    func cancel(_ id: UUID) {
        timers.removeAll { $0.id == id }
    }

    /// The soonest first (spec TM-8).
    var sortedTimers: [CountdownTimer] {
        let now = Date()
        return timers.sorted { $0.remaining(at: now) < $1.remaining(at: now) }
    }

    // MARK: - Stopwatch (spec TM-10…TM-13)

    func startOrPauseStopwatch() {
        if stopwatch.isRunning { stopwatch.pause(at: Date()) } else { stopwatch.start(at: Date()) }
    }

    func lap() { stopwatch.lap(at: Date()) }

    func resetStopwatch() { stopwatch.reset() }

    // MARK: - Pomodoro (spec TM-14…TM-17)

    func startOrPausePomodoro() {
        let now = Date()
        if pomodoro.isRunning {
            pomodoro.pause(at: now, plan: settings.plan)
            return
        }
        // A Focus started from its beginning runs its Shortcut (spec TM-16).
        if pomodoro.phase == .focus, pomodoro.remainingWhenPaused == nil { ShortcutsApp.run(settings.focusStartShortcut) }
        pomodoro.start(at: now, plan: settings.plan)
    }

    func skipPhase() {
        let wasFocus = pomodoro.phase == .focus && !pomodoro.isIdle
        if wasFocus { ShortcutsApp.run(settings.focusEndShortcut) }
        let autoStart = pomodoro.isRunning
        pomodoro.advance(at: Date(), plan: settings.plan, autoStart: autoStart)
        if autoStart, pomodoro.phase == .focus { ShortcutsApp.run(settings.focusStartShortcut) }
    }

    func resetPomodoro() {
        if pomodoro.phase == .focus, pomodoro.isRunning { ShortcutsApp.run(settings.focusEndShortcut) }
        pomodoro.reset()
    }

    // MARK: - Hover controls (spec TM-19, TM-20)

    func perform(_ control: ToolsControl, on clock: ToolsGlance.Clock?) {
        switch control {
        case .pause, .resume, .start: startOrPause(clock)
        case .addMinute: clock?.timerID.map(addMinute)
        case .cancel: clock?.timerID.map(cancel)
        case .lap: lap()
        case .reset: if clock?.tab == .stopwatch { resetStopwatch() } else { resetPomodoro() }
        case .next: skipPhase()
        case .unmute: _ = QuickToggleService.shared.toggle(.muteMicrophone)
        case .endAwake: QuickToggleService.shared.stopKeepingAwake()
        }
    }

    private func startOrPause(_ clock: ToolsGlance.Clock?) {
        switch clock?.tab {
        case .timer: clock?.timerID.map(pauseOrResume)
        case .stopwatch: startOrPauseStopwatch()
        case .pomodoro: startOrPausePomodoro()
        case nil: break
        }
    }

    // MARK: - Beside the notch (spec TM-3, TM-4, QT-5)

    var glance: ToolsGlance? {
        guard isRunning else { return nil }
        let toggles = QuickToggleService.shared
        var glance = ToolsGlance()
        let (clock, more) = ToolsGlance.pick(countdowns: countdownClocks, stopwatch: stopwatchClock)
        glance.clock = clock
        glance.more = more
        glance.micMuted = settings.togglesOn && settings.micBesideNotch && toggles.isOn(.muteMicrophone)
            && !settings.hiddenToggles.contains(.muteMicrophone)
        glance.awake = settings.togglesOn && settings.awakeBesideNotch && toggles.isOn(.keepAwake)
        return glance.isEmpty ? nil : glance
    }

    private var countdownClocks: [ToolsGlance.Clock] {
        var clocks: [ToolsGlance.Clock] = []
        if settings.timerOn {
            clocks += timers.map { timer in
                ToolsGlance.Clock(
                    tab: .timer, symbol: "hourglass", endDate: timer.endDate, fixed: timer.remainingWhenPaused ?? 0,
                    total: timer.duration, timerID: timer.id, title: timer.title
                )
            }
        }
        if settings.pomodoroOn, !pomodoro.isIdle {
            let plan = settings.plan
            clocks.append(ToolsGlance.Clock(
                tab: .pomodoro, symbol: pomodoro.phase.isBreak ? "cup.and.saucer.fill" : "circle.circle",
                endDate: pomodoro.endDate, fixed: pomodoro.remainingWhenPaused ?? 0, total: plan.length(of: pomodoro.phase),
                tint: pomodoro.phase.isBreak ? .green : .red, title: pomodoro.phase.title
            ))
        }
        return clocks
    }

    private var stopwatchClock: ToolsGlance.Clock? {
        // Running, or stopped and not yet reset, so its hover can reset it (spec TM-21).
        guard settings.stopwatchOn, settings.stopwatchBesideNotch, !stopwatch.isReset else { return nil }
        return ToolsGlance.Clock(
            tab: .stopwatch, symbol: "stopwatch", startedAt: stopwatch.startedAt, fixed: stopwatch.accumulated, title: "Stopwatch"
        )
    }

    // MARK: - Ends (spec TM-5, TM-6)

    private func updateTicker() {
        let counting = isRunning && (timers.contains { !$0.isPaused } || pomodoro.isRunning)
        if counting, ticker == nil {
            ticker = RepeatingTimer.start(every: 1, tolerance: 0.1) { [weak self] in self?.checkEnds(now: Date()) }
        } else if !counting, let ticker {
            ticker.invalidate()
            self.ticker = nil
        }
    }

    /// Ended while asleep: no sound, "Finished at" instead (spec TM-6).
    private static let lateAfter: TimeInterval = 5

    func checkEnds(now: Date) {
        guard isRunning else { return }
        for timer in timers {
            guard let end = timer.endDate, end <= now else { continue }
            timers.removeAll { $0.id == timer.id }
            finished(timer, at: end, now: now)
        }
        if let end = pomodoro.endDate, end <= now { pomodoroEnded(at: end, now: now) }
    }

    private func finished(_ timer: CountdownTimer, at end: Date, now: Date) {
        let late = now.timeIntervalSince(end) > Self.lateAfter
        let detail = late
            ? "Finished at \(end.formatted(date: .omitted, time: .shortened))" : "Time is up · \(ClockText.duration(timer.duration))"
        let notice = StickyNotice(
            title: timer.title, detail: detail, date: now, symbol: "hourglass", sourceName: "Timer", opens: .tools, stays: 60
        )
        notices?.show(notice)
        settings.tab = .timer
        QuickToggleService.shared.timerEnded()
        guard !late else { return }
        alarm.ring(settings.sound, repeating: true) { [weak self] in self?.notices?.notice == notice }
        if let appSettings { Haptics.perform(.open, settings: appSettings) }
    }

    private func pomodoroEnded(at end: Date, now: Date) {
        let finished = pomodoro.phase
        let late = now.timeIntervalSince(end) > Self.lateAfter
        if finished == .focus {
            history.record(at: end)
            ShortcutsApp.run(settings.focusEndShortcut)
        }
        let plan = settings.plan
        let (next, _) = PomodoroState.next(after: finished, doneInCycle: pomodoro.doneInCycle, plan: plan)
        let autoStart = next.isBreak ? settings.autoStartBreaks : settings.autoStartFocus
        pomodoro.advance(at: end, plan: plan, autoStart: autoStart)
        // A phase that started while asleep is already partly gone; one that ended too goes on.
        if let nextEnd = pomodoro.endDate, nextEnd <= now { pomodoro.endDate = now.addingTimeInterval(1) }
        if autoStart, next == .focus { ShortcutsApp.run(settings.focusStartShortcut) }
        let detail = "\(next.title) · \(ClockText.duration(plan.length(of: next)))" + (autoStart ? "" : " — start it in the notch")
        notices?.show(StickyNotice(
            title: late ? "\(finished.title) finished at \(end.formatted(date: .omitted, time: .shortened))" : "\(finished.title) done",
            detail: detail, date: now, symbol: next.isBreak ? "cup.and.saucer.fill" : "circle.circle", sourceName: "Pomodoro",
            opens: .tools, stays: 30
        ))
        settings.tab = .pomodoro
        guard !late else { return }
        alarm.ring(settings.sound, repeating: false) { false }
        if let appSettings { Haptics.perform(.open, settings: appSettings) }
    }

    // MARK: - Saving (spec TM-6)

    private struct Saved: Codable {
        var timers: [CountdownTimer]
        var stopwatch: StopwatchState
        var pomodoro: PomodoroState
        var history: PomodoroHistory
        var recent: [TimeInterval]
    }

    private static let savedKey = "toolsState"

    private func save() {
        guard !loading else { return }
        let saved = Saved(timers: timers, stopwatch: stopwatch, pomodoro: pomodoro, history: history, recent: recent)
        UserDefaults.standard.set(try? JSONEncoder().encode(saved), forKey: Self.savedKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.savedKey),
              let saved = try? JSONDecoder().decode(Saved.self, from: data)
        else { return }
        loading = true
        timers = saved.timers
        stopwatch = saved.stopwatch
        pomodoro = saved.pomodoro
        history = saved.history
        recent = saved.recent
        loading = false
    }
}

/// The sound at an end (spec TM-5): a timer's repeats every 3 s for a minute while its notice stays.
@MainActor
final class ToolsAlarm {
    private var task: Task<Void, Never>?

    static let sounds = ["Glass", "Ping", "Hero", "Funk", "Submarine", "Purr", "Blow", "Bottle", "Frog", "Morse", "Pop", "Sosumi", "Tink"]

    func ring(_ name: String, repeating: Bool, while stillShown: @escaping @MainActor () -> Bool) {
        task?.cancel()
        guard !name.isEmpty else { return }
        NSSound(named: NSSound.Name(name))?.play()
        guard repeating else { return }
        task = Task {
            for _ in 0..<19 {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled, stillShown() else { return }
                NSSound(named: NSSound.Name(name))?.play()
            }
        }
    }

    func stop() { task?.cancel() }
}
