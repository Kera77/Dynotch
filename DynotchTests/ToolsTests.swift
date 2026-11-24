@testable import Dynotch
import Foundation
import Testing

/// The Tools module: typed times, timers, the stopwatch, the pomodoro and the glance beside the notch.
struct ToolsTests {
    @Test func typedTimesFollowTheSpec() {
        #expect(DurationInput.parse("12") == 720)
        #expect(DurationInput.parse("1:30") == 90)
        #expect(DurationInput.parse("1:02:03") == 3723)
        #expect(DurationInput.parse("90s") == 90)
        #expect(DurationInput.parse("1h 15m") == 4500)
        #expect(DurationInput.parse("1h15m") == 4500)
        #expect(DurationInput.parse("2h") == 7200)
        #expect(DurationInput.parse("2.5") == 150)
    }

    @Test func nonsenseTimesAreRefused() {
        #expect(DurationInput.parse("") == nil)
        #expect(DurationInput.parse("0") == nil)
        #expect(DurationInput.parse("tea") == nil)
        #expect(DurationInput.parse("5 tea") == nil)
        #expect(DurationInput.parse("1:75") == nil)
        #expect(DurationInput.parse("25h") == nil)
    }

    @Test func clockTextRoundsACountdownUp() {
        #expect(ClockText.text(299.2) == "5:00")
        #expect(ClockText.text(59) == "0:59")
        #expect(ClockText.text(3899) == "1:04:59")
        #expect(ClockText.text(134.35, tenths: true) == "02:14.3")
        #expect(ClockText.duration(300) == "5 min")
        #expect(ClockText.duration(5400) == "1 h 30 min")
        #expect(ClockText.duration(45) == "45 s")
    }

    @Test func aPausedTimerKeepsWhatWasLeft() {
        let start = Date(timeIntervalSince1970: 1000)
        var timer = CountdownTimer(name: "", duration: 300, now: start)
        timer.pause(at: start.addingTimeInterval(100))
        #expect(timer.remaining(at: start.addingTimeInterval(10_000)) == 200)
        timer.resume(at: start.addingTimeInterval(1000))
        #expect(timer.remaining(at: start.addingTimeInterval(1050)) == 150)
        timer.addMinute()
        #expect(timer.remaining(at: start.addingTimeInterval(1050)) == 210)
        #expect(timer.title == "Timer")
    }

    @Test func stopwatchLapsAndExtremes() {
        let start = Date(timeIntervalSince1970: 0)
        var stopwatch = StopwatchState()
        stopwatch.start(at: start)
        stopwatch.lap(at: start.addingTimeInterval(10))
        stopwatch.lap(at: start.addingTimeInterval(15))
        stopwatch.lap(at: start.addingTimeInterval(30))
        stopwatch.pause(at: start.addingTimeInterval(40))
        #expect(stopwatch.elapsed(at: start.addingTimeInterval(1000)) == 40)
        let laps = stopwatch.laps
        #expect(laps.map(\.number) == [3, 2, 1])
        #expect(laps.map(\.time) == [15, 5, 10])
        let extremes = StopwatchState.extremes(of: laps)
        #expect(extremes?.fastest == 2)
        #expect(extremes?.slowest == 3)
        #expect(StopwatchState.extremes(of: Array(laps.prefix(2))) == nil)
    }

    @Test func pomodoroCyclesToALongBreak() {
        let plan = PomodoroPlan(longBreakAfter: 2)
        #expect(PomodoroState.next(after: .focus, doneInCycle: 0, plan: plan) == (.shortBreak, 1))
        #expect(PomodoroState.next(after: .shortBreak, doneInCycle: 1, plan: plan) == (.focus, 1))
        #expect(PomodoroState.next(after: .focus, doneInCycle: 1, plan: plan) == (.longBreak, 2))
        #expect(PomodoroState.next(after: .longBreak, doneInCycle: 2, plan: plan) == (.focus, 0))
    }

    @Test func pomodoroWaitsOrRunsAfterAPhase() {
        let now = Date(timeIntervalSince1970: 0)
        var state = PomodoroState()
        state.start(at: now, plan: PomodoroPlan())
        state.advance(at: now.addingTimeInterval(1500), plan: PomodoroPlan(), autoStart: true)
        #expect(state.phase == .shortBreak)
        #expect(state.endDate == now.addingTimeInterval(1800))
        state.advance(at: now.addingTimeInterval(1800), plan: PomodoroPlan(), autoStart: false)
        #expect(state.phase == .focus)
        #expect(!state.isRunning)
        #expect(state.remaining(at: now, plan: PomodoroPlan()) == 1500)
    }

    @Test func historyCountsTheLastWeek() {
        var history = PomodoroHistory()
        let now = Date()
        history.record(at: now)
        history.record(at: now)
        let week = history.lastWeek(endingAt: now)
        #expect(week.count == 7)
        #expect(week.last?.done == 2)
        #expect(week.first?.done == 0)
    }

    @Test func theSoonestCountdownStandsBesideTheNotch() {
        let now = Date()
        let later = ToolsGlance.Clock(tab: .timer, symbol: "hourglass", endDate: now.addingTimeInterval(600), total: 900)
        let sooner = ToolsGlance.Clock(tab: .pomodoro, symbol: "circle.circle", endDate: now.addingTimeInterval(30), total: 1500)
        let paused = ToolsGlance.Clock(tab: .timer, symbol: "hourglass", fixed: 20, total: 60)
        let stopwatch = ToolsGlance.Clock(tab: .stopwatch, symbol: "stopwatch", startedAt: now)
        let (shown, more) = ToolsGlance.pick(countdowns: [later, paused, sooner], stopwatch: stopwatch)
        #expect(shown == sooner)
        #expect(more == 1)
        #expect(sooner.endsSoon(at: now))
        #expect(!later.endsSoon(at: now))
        #expect(ToolsGlance.pick(countdowns: [paused], stopwatch: stopwatch).0 == paused)
        #expect(ToolsGlance.pick(countdowns: [], stopwatch: stopwatch).0 == stopwatch)
    }

    @Test func aCountdownEndingSoonComesRightAfterTheMeetings() {
        let now = Date()
        var glance = ToolsGlance()
        glance.clock = ToolsGlance.Clock(tab: .timer, symbol: "hourglass", endDate: now.addingTimeInterval(30), total: 60)
        let soon = IndicatorItem.items(meetings: [], usage: [], tasks: nil, tools: glance, now: now)
        #expect(soon.first?.id == "tools")
        glance.clock = ToolsGlance.Clock(tab: .timer, symbol: "hourglass", endDate: now.addingTimeInterval(600), total: 900)
        let later = IndicatorItem.items(meetings: [], usage: [], tasks: nil, tools: glance, now: now)
        #expect(later.last?.id == "tools")
    }

    @Test func hoverControlsFollowTheShownTool() {
        let now = Date()
        var glance = ToolsGlance()
        glance.clock = ToolsGlance.Clock(tab: .timer, symbol: "hourglass", endDate: now.addingTimeInterval(60), total: 60)
        #expect(glance.controls == [.pause, .addMinute, .cancel])
        glance.clock = ToolsGlance.Clock(tab: .stopwatch, symbol: "stopwatch", startedAt: now)
        #expect(glance.controls == [.pause, .lap, .reset])
        glance.clock = ToolsGlance.Clock(tab: .stopwatch, symbol: "stopwatch", fixed: 12)
        #expect(glance.controls == [.start, .reset])
        glance.clock = ToolsGlance.Clock(tab: .pomodoro, symbol: "circle.circle", fixed: 300, total: 1500)
        #expect(glance.controls == [.start, .next, .reset])
        glance.clock = nil
        glance.micMuted = true
        #expect(glance.controls == [.unmute])
    }

    @Test func toolsDropTheirControlsOrWidenBesideTheNotch() {
        var glance = ToolsGlance()
        glance.clock = ToolsGlance.Clock(tab: .stopwatch, symbol: "stopwatch", startedAt: Date())
        let items = [IndicatorItem.tools(glance)]
        // Hover shows controls instead of opening the module (spec TM-19).
        #expect(items[0].opensModule == nil)
        #expect(items[0].labelHeight == IndicatorLayout.labelHeight)
        let beside = IndicatorItem.unfoldingUsage(items, hovered: 0, wings: true)
        #expect(beside[0].labelHeight == 0)
        #expect(beside[0].slotWidth > items[0].slotWidth)
        #expect(IndicatorItem.unfoldingUsage(items, hovered: 0, wings: false) == items)
        // Wings mode with notices dropping down: the Tools still widen sideways.
        #expect(IndicatorItem.unfoldingUsage(items, hovered: 0, wings: false, toolsBeside: true)[0].labelHeight == 0)
    }
}
