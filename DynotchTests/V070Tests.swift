import AppKit
@testable import Dynotch
import Foundation
import Testing

struct V070Tests {
    @Test func gradientTakesAnOptionalMiddleColor() throws {
        var style = MenuBarTintStyle()
        style.kind = .gradient
        #expect(style.colors(dark: false) == [style.light.start, style.light.end])
        style.usesMiddle = true
        #expect(style.colors(dark: false) == [style.light.start, MenuBarTintStyle.defaultMiddle, style.light.end])
        style.light.middle = "#112233"
        #expect(style.colors(dark: false)[1] == "#112233")
        style.kind = .solid
        #expect(style.colors(dark: false) == [style.light.start, style.light.start])
        // Settings saved before v0.70 have no middle colour and still load.
        let json = "{\"kind\":\"Gradient\",\"direction\":\"Left to right\",\"light\":{\"start\":\"#000000\",\"end\":\"#FFFFFF\"},"
            + "\"dark\":{\"start\":\"#000000\",\"end\":\"#FFFFFF\"},\"sameInBoth\":true,\"opacity\":0.5}"
        let old = Data(json.utf8)
        let decoded = try JSONDecoder().decode(MenuBarTintStyle.self, from: old)
        #expect(decoded.usesMiddle == nil)
        #expect(decoded.colors(dark: false).count == 2)
    }

    @Test func systemAlertOffKeepsMemoryOffAndSwapOn() throws {
        let defaults = try #require(UserDefaults(suiteName: "V070Tests.alerts"))
        defaults.removePersistentDomain(forName: "V070Tests.alerts")
        let split = NotificationPreferences.splitSystemAlert(["system"], defaults: defaults)
        #expect(split.contains("memory"))
        #expect(!split.contains("swap"))
        // Only once.
        #expect(NotificationPreferences.splitSystemAlert(["system"], defaults: defaults) == ["system"])
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

    @Test func areaRecordingRectIsOnWholeEvenPixels() throws {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let area = CGRect(x: 100.3, y: 200.2, width: 300.5, height: 151.1)
        let rect = try #require(ScreenRecorder.sourceRect(area, screen: screen, scale: 2))
        let pixels = CGRect(x: rect.minX * 2, y: rect.minY * 2, width: rect.width * 2, height: rect.height * 2)
        #expect(pixels.minX == pixels.minX.rounded() && pixels.minY == pixels.minY.rounded())
        #expect(Int(pixels.width) % 2 == 0 && Int(pixels.height) % 2 == 0)
        // Top-left origin: the area's top edge, 982 − 351.3 points down from the top.
        #expect(abs(rect.minY - (982 - 351.3)) < 0.5)
        #expect(ScreenRecorder.sourceRect(CGRect(x: 0, y: 0, width: 4, height: 4), screen: screen, scale: 2) == nil)
    }
}
