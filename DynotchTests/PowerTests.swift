import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// Background looks: gates, pause, slow-down and the Mission Control watch (spec RF-7…RF-10).
struct PowerTests {
    @Test func pollerModeFollowsStartGateAndPause() {
        #expect(Poller.mode(started: false, paused: false, active: true, interval: 2) == .stopped)
        #expect(Poller.mode(started: true, paused: true, active: true, interval: 2) == .stopped)
        #expect(Poller.mode(started: true, paused: false, active: false, interval: 2) == .idle)
        #expect(Poller.mode(started: true, paused: false, active: true, interval: 2) == .running(2))
        #expect(Poller.mode(started: true, paused: false, active: true, interval: 0) == .stopped)
    }

    @Test func slowFactorStretchesOnlyBackgroundLooks() {
        #expect(Poller.scaled(2, factor: 3, scales: true) == 6)
        #expect(Poller.scaled(1, factor: 3, scales: false) == 1)
        #expect(Poller.scaled(5, factor: 0.5, scales: true) == 5)
    }

    @MainActor
    @Test func pollerLooksOnceWhenItsGateTurnsOn() {
        var isOn = false
        var looks = 0
        let poller = Poller(every: 60, isActive: { isOn }, action: { looks += 1 })
        poller.start()
        #expect(poller.mode == .idle)
        poller.reevaluate()
        #expect(looks == 0)
        isOn = true
        poller.reevaluate()
        #expect(poller.mode == .running(60))
        #expect(looks == 1)
        // Already running: checking again does not look again.
        poller.reevaluate()
        #expect(looks == 1)
        var cleared = false
        poller.onInactive = { cleared = true }
        isOn = false
        poller.reevaluate()
        #expect(poller.mode == .idle)
        #expect(cleared)
        poller.stop()
        #expect(poller.mode == .stopped)
    }

    @MainActor
    @Test func startingDoesNotLookUnlessAsked() {
        var looks = 0
        let quiet = Poller(every: 60) { looks += 1 }
        quiet.start()
        #expect(looks == 0)
        quiet.interval = 30
        #expect(quiet.mode == .running(30))
        #expect(looks == 0)
        quiet.stop()
        let eager = Poller(every: 60) { looks += 1 }
        eager.start(now: true)
        #expect(looks == 1)
        eager.stop()
    }

    @Test func pauseAndSlowDownFromTheMacsState() {
        #expect(!PowerConditions().isPaused)
        #expect(PowerConditions().slowFactor == 1)
        #expect(PowerConditions(screensAsleep: true).isPaused)
        #expect(PowerConditions(sessionInactive: true).isPaused)
        #expect(PowerConditions(locked: true).isPaused)
        #expect(PowerConditions(lowPowerMode: true).slowFactor == 3)
        #expect(PowerConditions(onBattery: true).slowFactor == 3)
        #expect(!PowerConditions(onBattery: true).isPaused)
    }

    @Test func missionControlIsWatchedCloselyOnlyAfterAHint() {
        let now = Date()
        let fast = MissionControlWatcher.fastInterval
        let slow = MissionControlWatcher.slowInterval
        #expect(MissionControlWatcher.pollInterval(isShown: false, burstUntil: .distantPast, now: now) == slow)
        #expect(MissionControlWatcher.pollInterval(isShown: false, burstUntil: now.addingTimeInterval(2), now: now) == fast)
        #expect(MissionControlWatcher.pollInterval(isShown: true, burstUntil: .distantPast, now: now) == fast)
        #expect(slow <= 2)
    }

    @Test func windowListTicksAtTheShortestWantedInterval() {
        #expect(WindowListMonitor.tick(for: [2, 1, 6], hasSubscribers: true) == 1)
        #expect(WindowListMonitor.tick(for: [], hasSubscribers: true) == Poller.idleCheck)
        #expect(WindowListMonitor.tick(for: [], hasSubscribers: false) == 0)
    }

    @Test func callsTakeTheScreenAsKnownAfterAGap() {
        let now = Date()
        #expect(CallBaseline.isStale(lastTick: .distantPast, now: now))
        #expect(!CallBaseline.isStale(lastTick: now.addingTimeInterval(-3), now: now))
        #expect(CallBaseline.isStale(lastTick: now.addingTimeInterval(-30), now: now))
    }

    @Test func missionControlNotifications() {
        #expect(MissionControlWatcher.isShowing(after: "AXExposeShowAllWindows"))
        #expect(MissionControlWatcher.isShowing(after: "AXExposeShowDesktop"))
        #expect(!MissionControlWatcher.isShowing(after: "AXExposeExit"))
    }

    @Test func missionControlIsADockWindowOverAWholeDisplay() {
        let screen = CGRect(x: 0, y: 0, width: 2560, height: 1440)
        func dock(_ width: Int, _ height: Int, layer: Int = 20) -> ListedWindow {
            ListedWindow(owner: "Dock", layer: layer, frame: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let spacesBar = ListedWindow(owner: "WindowManager", layer: 14, frame: CGRect(x: 0, y: 0, width: 2560, height: 134))
        #expect(MissionControlWatcher.isMissionControl([dock(2560, 1440), spacesBar], screens: [screen]))
        // The Dock sliding in under the pointer puts up the same window, without WindowManager's (N-19c).
        #expect(!MissionControlWatcher.isMissionControl([dock(2560, 1440)], screens: [screen]))
        #expect(!MissionControlWatcher.isMissionControl([spacesBar], screens: [screen]))
        // The Dock bar itself, or another layer, is not Mission Control.
        #expect(!MissionControlWatcher.isMissionControl([dock(2560, 80)], screens: [screen]))
        #expect(!MissionControlWatcher.isMissionControl([dock(2560, 1440, layer: 0)], screens: [screen]))
    }
}
