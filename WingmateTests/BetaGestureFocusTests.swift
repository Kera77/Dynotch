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

    @Test func focusLengthsMatchControlCenter() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Budapest"))
        let noon = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 28, hour: 12)))
        let night = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 28, hour: 21)))
        #expect(FocusLength.evening.title(now: noon, calendar: calendar) == "Until this evening")
        #expect(FocusLength.evening.title(now: night, calendar: calendar) == "Until tomorrow morning")
        #expect(FocusLength.hour.matches("For 1 hour"))
        #expect(FocusLength.evening.matches("Until tomorrow morning"))
        #expect(FocusLength.event.matches("Until the end of this event"))
        #expect(!FocusLength.untilOff.matches("For 1 hour"))
        #expect(FocusLength.offered(duringEvent: false) == [.hour, .evening, .untilOff])
        // The lengths under the active Focus are no Focuses; a Focus named so is kept.
        let rows = ["Do Not Disturb", "Work", "For 1 hour", "Until this evening", "Sleep", "Until Friday"]
        #expect(ControlCenterFocus.names(in: rows, known: ["Until Friday"]) == ["Do Not Disturb", "Work", "Sleep", "Until Friday"])
        // Control Center's header gives the end: the next such time.
        let end = try #require(FocusModeService.endTime(in: "On Until 13:52", now: noon, calendar: calendar))
        #expect(calendar.dateComponents([.day, .hour, .minute], from: end) == DateComponents(day: 28, hour: 13, minute: 52))
        let morning = try #require(FocusModeService.endTime(in: "On Until 7:00 AM", now: night, calendar: calendar))
        #expect(calendar.dateComponents([.day, .hour], from: morning) == DateComponents(day: 29, hour: 7))
        #expect(FocusModeService.endTime(in: "On", now: noon, calendar: calendar) == nil)
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

    @Test func aFocusSymbolOtherAppsCannotDrawIsReplaced() {
        #expect(FocusMode.usableSymbol("briefcase.fill", id: "com.apple.focus.work", modeName: "Work") == "briefcase.fill")
        #expect(FocusMode.usableSymbol("no.such.glyph", id: "com.apple.focus.work", modeName: "Work") == "briefcase.fill")
        #expect(FocusMode.usableSymbol(nil, id: "com.apple.focus.reduce-interruptions", modeName: "Reduce Interruptions") == "sparkles")
        let emoji = "com.apple.donotdisturb.mode.emoji.face.grinning"
        #expect(FocusMode.usableSymbol("", id: emoji, modeName: "Mine") == "face.smiling.inverse")
        #expect(FocusMode.usableSymbol(nil, id: "custom.1", modeName: "Sleep time") == "bed.double.fill")
        #expect(FocusMode.usableSymbol(nil, id: "custom.2", modeName: "Other") == "moon.fill")
    }

    @MainActor @Test func theFocusDropsDownOnHoverEvenWhenDropDownsWaitForASwipe() {
        let work = FocusMode(id: "work", name: "Work", symbol: "briefcase.fill", tint: nil)
        #expect(IndicatorItem.focus(FocusModeService.Active(mode: work, until: nil)).dropsDownOnHover)
        #expect(!IndicatorItem.working.dropsDownOnHover)
    }

    @MainActor @Test func anExpiredLengthIsForgotten() throws {
        let defaults = try #require(UserDefaults(suiteName: "BetaGestureFocusTests-\(UUID().uuidString)"))
        let service = FocusModeService(defaults: defaults)
        let work = FocusMode(id: "work", name: "Work", symbol: "briefcase.fill", tint: nil)
        defaults.set("work", forKey: "focusUntilMode")
        defaults.set(Date().addingTimeInterval(-1), forKey: "focusUntil")
        service.apply(FocusFiles.Snapshot(modes: [work], activeID: "work"))
        #expect(service.active == FocusModeService.Active(mode: work, until: nil))
        service.apply(FocusFiles.Snapshot(modes: [work], activeID: nil))
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
