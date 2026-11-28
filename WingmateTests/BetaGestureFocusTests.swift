import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

/// Swipe drop-downs, the Focus picker, the edge sliders (spec DS-2, FC-2…FC-4, ES-1…ES-3).
struct BetaGestureFocusTests {
    @Test func aSwipeDownOpensOncePerGesture() {
        var swipe = RevealSwipe()
        #expect(swipe.handle(fingerDown: 12, across: 1, began: true, isMomentum: false, time: 0) == nil)
        #expect(swipe.handle(fingerDown: 12, across: 1, began: false, isMomentum: false, time: 0.02) == .open)
        #expect(swipe.handle(fingerDown: 40, across: 0, began: false, isMomentum: false, time: 0.04) == nil)
        // The run-out after letting go does nothing.
        #expect(swipe.handle(fingerDown: -40, across: 0, began: nil, isMomentum: true, time: 0.06) == nil)
    }

    @Test func aSidewaysSwipeOrAWheelTurnUpIsNotAnOpen() {
        var swipe = RevealSwipe()
        #expect(swipe.handle(fingerDown: 25, across: 30, began: true, isMomentum: false, time: 0) == nil)
        var wheel = RevealSwipe()
        #expect(wheel.handle(fingerDown: -25, across: 0, began: nil, isMomentum: false, time: 5) == .close)
        // A new wheel turn after a pause counts again.
        #expect(wheel.handle(fingerDown: 25, across: 0, began: nil, isMomentum: false, time: 6) == .open)
    }

    @Test func focusLengthsEnd() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Budapest"))
        let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 28, hour: 21)))
        #expect(FocusLength.hour.end(from: evening, calendar: calendar) == evening.addingTimeInterval(3600))
        #expect(FocusLength.twoHours.end(from: evening, calendar: calendar) == evening.addingTimeInterval(7200))
        let morning = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 29, hour: 7)))
        #expect(FocusLength.tomorrowMorning.end(from: evening, calendar: calendar) == morning)
        // After midnight "tomorrow morning" is this morning at 7.
        let night = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 29, hour: 2)))
        #expect(FocusLength.tomorrowMorning.end(from: night, calendar: calendar) == morning)
    }

    @Test func focusTimeLeft() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(FocusModeService.remainingText(until: nil, now: now) == nil)
        #expect(FocusModeService.remainingText(until: now.addingTimeInterval(42 * 60), now: now) == "42 min left")
        #expect(FocusModeService.remainingText(until: now.addingTimeInterval(7200), now: now) == "2 h left")
        #expect(FocusModeService.remainingText(until: now.addingTimeInterval(-5), now: now) == nil)
    }

    @Test func focusFilesAreRead() {
        let configurations: [String: Any] = ["data": [["modeConfigurations": [
            "com.apple.focus.work": ["mode": ["name": "Work", "modeIdentifier": "com.apple.focus.work",
                                              "symbolImageName": "briefcase.fill", "tintColorName": "systemTealColor"]],
            "com.apple.donotdisturb.mode.default": ["mode": ["modeIdentifier": "com.apple.donotdisturb.mode.default"]]
        ]]]]
        let modes = FocusFiles.modes(in: configurations)
        #expect(modes.map(\.name) == ["Do Not Disturb", "Work"])
        #expect(modes.first?.symbol == "moon.fill")
        let assertions: [String: Any] = ["data": [["storeAssertionRecords": [["assertionDetails": [
            "assertionDetailsModeIdentifier": "com.apple.focus.work"
        ]]]]]]
        #expect(FocusFiles.activeID(in: assertions) == "com.apple.focus.work")
        #expect(FocusFiles.activeID(in: ["data": [["storeAssertionRecords": []]]]) == nil)
    }

    @MainActor @Test func anExpiredLengthTurnsTheFocusOff() throws {
        let defaults = try #require(UserDefaults(suiteName: "BetaGestureFocusTests-\(UUID().uuidString)"))
        let service = FocusModeService(defaults: defaults)
        let work = FocusMode(id: "work", name: "Work", symbol: "briefcase.fill", tint: nil)
        let now = Date()
        service.noteLength(of: work, until: now.addingTimeInterval(-1))
        service.apply(FocusFiles.Snapshot(modes: [work], activeID: "work"), now: now)
        #expect(service.active == nil)
    }

    @Test func edgeSlidesStepAlongTheEdge() {
        var tracker = EdgeSliderTracker()
        tracker.steps = 16
        #expect(tracker.handle(touches: [CGPoint(x: 0.03, y: 0.3)]) == nil)
        #expect(tracker.handle(touches: [CGPoint(x: 0.03, y: 0.34)]) == .began(.left))
        let step = EdgeSliderTracker.stepLength(steps: 16, zone: .left)
        #expect(tracker.handle(touches: [CGPoint(x: 0.03, y: 0.34 + step * 2.2)]) == .moved(.left, steps: 2))
        #expect(tracker.handle(touches: [CGPoint(x: 0.03, y: 0.34 - step * 1.1)]) == .moved(.left, steps: -1))
        // A second finger ends it.
        #expect(tracker.handle(touches: [CGPoint(x: 0.03, y: 0.3), CGPoint(x: 0.5, y: 0.5)]) == .ended(.left))
    }

    @Test func anOrdinaryPointerMoveFromTheEdgeIsNoSlide() {
        var tracker = EdgeSliderTracker()
        #expect(tracker.handle(touches: [CGPoint(x: 0.97, y: 0.5)]) == nil)
        #expect(tracker.handle(touches: [CGPoint(x: 0.9, y: 0.52)]) == nil)
        #expect(tracker.handle(touches: [CGPoint(x: 0.9, y: 0.7)]) == nil)
        #expect(tracker.handle(touches: []) == nil)
        // The top edge runs left to right; the corners belong to no edge.
        #expect(EdgeSliderTracker.zone(at: CGPoint(x: 0.5, y: 0.97)) == .top)
        #expect(EdgeSliderTracker.zone(at: CGPoint(x: 0.02, y: 0.97)) == nil)
        tracker.enabled = [.left]
        #expect(tracker.handle(touches: [CGPoint(x: 0.97, y: 0.5)]) == nil)
        #expect(tracker.handle(touches: [CGPoint(x: 0.97, y: 0.6)]) == nil)
    }

    @Test func levelsStayOnTheirGrid() {
        #expect(EdgeSliderTracker.level(from: 0.5, steps: 1, count: 16) == 9.0 / 16)
        #expect(EdgeSliderTracker.level(from: 0.42, steps: 1, count: 100) == 0.43)
        #expect(EdgeSliderTracker.level(from: 0.98, steps: 5, count: 100) == 1)
        #expect(EdgeSliderTracker.level(from: 0.02, steps: -5, count: 100) == 0)
    }
}
