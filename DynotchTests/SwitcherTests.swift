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
}
