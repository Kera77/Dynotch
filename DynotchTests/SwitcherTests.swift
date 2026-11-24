import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// The window switcher (spec AS-1…AS-13).
struct SwitcherTests {
    private func window(
        _ id: CGWindowID, pid: pid_t, width: Int = 800, height: Int = 600, layer: Int = 0, onScreen: Bool = true
    ) -> [String: Any] {
        [kCGWindowNumber as String: id, kCGWindowOwnerPID as String: pid, kCGWindowLayer as String: layer,
         kCGWindowIsOnscreen as String: onScreen, kCGWindowName as String: "Window \(id)",
         kCGWindowBounds as String: ["X": 0, "Y": 0, "Width": width, "Height": height]]
    }

    private let apps: [pid_t: SwitcherWindows.AppInfo] = [
        10: .init(name: "Zen", bundleID: "app.zen", isHidden: false),
        20: .init(name: "Code", bundleID: "com.code", isHidden: false),
        30: .init(name: "Hidden", bundleID: "com.hidden", isHidden: true)
    ]

    @Test func normalWindowsOfRegularAppsInOrder() {
        let info = [
            window(1, pid: 10), window(2, pid: 20), window(3, pid: 10, width: 40), window(4, pid: 20, layer: 25),
            window(5, pid: 99), window(6, pid: 30), window(7, pid: 1)
        ]
        let items = SwitcherWindows.items(from: info, apps: apps, minimized: [], ownPID: 1, options: .init())
        #expect(items.map(\.windowID) == [1, 2])
    }

    @Test func scopeGroupingAndExclusions() {
        let info = [window(1, pid: 10), window(2, pid: 10), window(3, pid: 20, onScreen: false), window(4, pid: 30)]
        var options = SwitcherWindows.Options()
        #expect(SwitcherWindows.items(from: info, apps: apps, minimized: [], ownPID: 1, options: options).map(\.windowID) == [1, 2])
        options.scope = .allSpaces
        options.showsHidden = true
        #expect(SwitcherWindows.items(from: info, apps: apps, minimized: [], ownPID: 1, options: options).map(\.windowID) == [1, 2, 3, 4])
        options.groupsByApp = true
        #expect(SwitcherWindows.items(from: info, apps: apps, minimized: [], ownPID: 1, options: options).map(\.windowID) == [1, 3, 4])
        options.excluded = ["app.zen"]
        #expect(SwitcherWindows.items(from: info, apps: apps, minimized: [], ownPID: 1, options: options).map(\.windowID) == [3, 4])
    }

    @Test func minimizedOnlyWhenAsked() {
        let info = [window(1, pid: 10), window(2, pid: 20, onScreen: false)]
        var options = SwitcherWindows.Options()
        #expect(SwitcherWindows.items(from: info, apps: apps, minimized: [2], ownPID: 1, options: options).count == 1)
        options.showsMinimized = true
        let items = SwitcherWindows.items(from: info, apps: apps, minimized: [2], ownPID: 1, options: options)
        #expect(items.map(\.windowID) == [1, 2])
        #expect(items.last?.isMinimized == true)
    }

    @Test func layoutFitsTheRoomAndWraps() {
        let room = CGSize(width: 900, height: 700)
        let few = SwitcherLayout.size(count: 3, style: .icons, scale: 1, notchHeight: 32, room: room)
        let many = SwitcherLayout.size(count: 30, style: .icons, scale: 1, notchHeight: 32, room: room)
        #expect(few.width < many.width)
        #expect(many.width <= room.width)
        #expect(many.height <= room.height)
        #expect(SwitcherLayout.columns(count: 30, style: .titles, scale: 1, maxWidth: 900) == 1)
    }

    @MainActor @Test func offByDefaultWithoutShortcutThreeFingers() throws {
        let defaults = try #require(UserDefaults(suiteName: "SwitcherTests-\(UUID().uuidString)"))
        let settings = SwitcherSettings(defaults: defaults)
        #expect(!settings.isOn)
        #expect(settings.shortcut == nil)
        #expect(settings.swipeFingers == 3)
        #expect(!settings.showsPreviews)
        #expect(settings.scope == .currentSpace)
    }

    @Test func swipeStepsFollowTheDistancePerWindow() {
        #expect(SwitcherController.steps(travel: 0.3, step: 0.05) == 6)
        #expect(SwitcherController.steps(travel: 0.3, step: 0.25) == 1)
        #expect(SwitcherController.steps(travel: -0.12, step: 0.05) == -2)
    }

    @Test func onlyCoveredLeavesOutTheWindowsYouCanSee() {
        func placed(_ id: CGWindowID, pid: pid_t, x: Int, onScreen: Bool = true) -> [String: Any] {
            var entry = window(id, pid: pid, onScreen: onScreen)
            entry[kCGWindowBounds as String] = ["X": x, "Y": 0, "Width": 800, "Height": 600]
            return entry
        }
        // Front to back: 1 in front, 2 fully under it, 3 mostly beside it, 4 on another Space.
        let info = [placed(1, pid: 10, x: 0), placed(2, pid: 20, x: 0), placed(3, pid: 10, x: 600),
                    placed(4, pid: 20, x: 0, onScreen: false)]
        var options = SwitcherWindows.Options()
        options.onlyCovered = true
        options.scope = .allSpaces
        let ids = SwitcherWindows.items(from: info, apps: apps, minimized: [], ownPID: 1, options: options).map(\.windowID)
        #expect(ids == [2, 4])
        // Window 3 lies a quarter under the windows in front of it.
        #expect(SwitcherWindows.coverage(of: CGRect(x: 600, y: 0, width: 800, height: 600),
                                         by: [CGRect(x: 0, y: 0, width: 800, height: 600)]) == 0.25)
        options.coverThreshold = 0.2
        let lower = SwitcherWindows.items(from: info, apps: apps, minimized: [], ownPID: 1, options: options).map(\.windowID)
        #expect(lower == [2, 3, 4])
    }

    @Test func quickSwipeGoesToAnotherApp() {
        let item = { (window: CGWindowID, pid: pid_t) in
            SwitcherItem(windowID: window, pid: pid, bundleID: nil, appName: "", title: "", bounds: .zero)
        }
        let items = [item(1, 10), item(2, 10), item(3, 20), item(4, 30)]
        #expect(SwitcherController.previousApp(items, front: 10)?.windowID == 3)
        #expect(SwitcherController.previousApp(items, front: nil)?.windowID == 3)
        #expect(SwitcherController.previousApp([item(1, 10)], front: 10) == nil)
    }

    @MainActor @Test func historyPutsTheLatestFirst() throws {
        let defaults = try #require(UserDefaults(suiteName: "SwitcherTests.history"))
        defaults.removePersistentDomain(forName: "SwitcherTests.history")
        let history = ModuleHistory(defaults: defaults)
        history.opened(.notes)
        history.opened(.calendar)
        history.opened(.notes)
        #expect(ModuleHistory(defaults: defaults).recent == [.notes, .calendar])
    }

    @Test func startsOnTheRowsLatestModule() {
        let row: [FeatureID] = [.calendar, .notes, .calculator]
        let history: [FeatureID] = [.terminal, .calculator, .calendar]
        // The row keeps its order; the latest opened of it is chosen, also while open (spec QS-11, QS-16).
        #expect(ModuleSwitcher.startIndex(row, history: history) == 2)
        // No history: the first.
        #expect(ModuleSwitcher.startIndex(row, history: []) == 0)
        #expect(ModuleSwitcher.startIndex([.notes], history: [.notes]) == 0)
    }

    @Test func oneRowShrinksOnlyWhenItMust() {
        // Plenty of room: the chosen size stays (spec QS-12).
        #expect(ModuleSwitcher.rowScale(count: 6, scale: 1, width: 1400) == 1)
        let scale = ModuleSwitcher.rowScale(count: 20, scale: 1, width: 1000)
        #expect(scale < 1)
        let tile = SwitcherLayout.tile(.icons, scale: scale).width
        #expect(20 * tile + 19 * SwitcherLayout.spacing + 2 * SwitcherLayout.padding <= 1000.5)
    }

    @MainActor @Test func rowIsSeededOnceThenEdited() throws {
        let defaults = try #require(UserDefaults(suiteName: "SwitcherTests.row"))
        defaults.removePersistentDomain(forName: "SwitcherTests.row")
        let settings = SwitcherSettings(defaults: defaults)
        settings.seedModuleRow([.calendar, .notes])
        #expect(settings.moduleRow == [.calendar, .notes])
        settings.addToModuleRow(.terminal)
        settings.addToModuleRow(.notes)
        settings.moveInModuleRow(from: IndexSet(integer: 2), to: 0)
        settings.removeFromModuleRow(.calendar)
        #expect(settings.moduleRow == [.terminal, .notes])
        // A later launch keeps the edited row, even an empty one (spec QS-10).
        settings.removeFromModuleRow(.terminal)
        settings.removeFromModuleRow(.notes)
        let again = SwitcherSettings(defaults: defaults)
        again.seedModuleRow([.calendar])
        #expect(again.moduleRow.isEmpty)
    }
}
