import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// Top row order, the calendar's two weeks, Mission Control.
struct V044Tests {
    @Test func topRowOrderKeepsStoredAndAddsNewControls() {
        #expect(TopRowLayout.normalized([]) == TopRowControl.allCases)
        #expect(TopRowLayout.normalized(["settings", "pin", "bogus", "pin"]) == [.tablet, .followMouse, .keyboardLock, .settings, .pin])
    }

    @MainActor @Test func topRowMovesAndHidesButNeverSettings() throws {
        let defaults = try #require(UserDefaults(suiteName: "V044Tests-\(UUID().uuidString)"))
        let layout = TopRowLayout(defaults: defaults)
        layout.move(.settings, to: .tablet)
        #expect(layout.order.first == .settings)
        layout.setShown(.settings, false)
        layout.setShown(.tablet, false)
        #expect(layout.visible.contains(.settings))
        #expect(!layout.visible.contains(.tablet))
        // Kept for the next launch.
        #expect(TopRowLayout(defaults: defaults).order.first == .settings)
    }

    @Test func dayStripSpansTwoWeeksEachWay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18)))
        let days = DayStripView.days(around: today, selected: today, calendar: calendar)
        #expect(days.count == 29)
        #expect(days.first == calendar.date(byAdding: .day, value: -14, to: today))
        #expect(days.last == calendar.date(byAdding: .day, value: 14, to: today))
        // A day further away (from the full calendar) is still shown.
        let far = try #require(calendar.date(byAdding: .day, value: 40, to: today))
        #expect(DayStripView.days(around: today, selected: far, calendar: calendar).contains(far))
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
