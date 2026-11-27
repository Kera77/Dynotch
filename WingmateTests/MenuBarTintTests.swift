import AppKit
import Foundation
import Testing
@testable import Wingmate

/// The menu bar tint.
struct MenuBarTintTests {
    @Test func hexColorsRoundTrip() throws {
        let rgb = try #require(TintColor.rgb("#7F5AF0"))
        #expect(TintColor.hex(red: rgb.red, green: rgb.green, blue: rgb.blue) == "#7F5AF0")
        #expect(TintColor.rgb("nope") == nil)
    }

    @Test func theStripCoversTheMenuBarOnly() throws {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let frame = try #require(MenuBarTintService.menuBarFrame(screen: screen, visible: CGRect(x: 0, y: 0, width: 1512, height: 945)))
        #expect(frame == CGRect(x: 0, y: 945, width: 1512, height: 37))
        // The menu bar's own window is a point lower than the room on a display with a notch.
        let drawn = MenuBarTintService.menuBarFrame(screen: screen, visible: CGRect(x: 0, y: 0, width: 1512, height: 943), drawn: 38)
        #expect(drawn?.height == 38)
        #expect(drawn?.maxY == 982)
        // The notch's place is left clear.
        let gap = MenuBarTintService.notchGap(
            screenWidth: 1512, left: CGRect(x: 0, y: 945, width: 660, height: 37),
            right: CGRect(x: 852, y: 945, width: 660, height: 37), screenMinX: 0
        )
        #expect(gap == 660...852)
        #expect(MenuBarTintService.notchGap(screenWidth: 1512, left: nil, right: nil, screenMinX: 0) == nil)
        // A menu bar that hides by itself leaves no room: no strip.
        #expect(MenuBarTintService.menuBarFrame(screen: screen, visible: screen) == nil)
    }

    @Test func darkModeUsesItsOwnPairUnlessShared() {
        var style = MenuBarTintStyle()
        style.sameInBoth = false
        #expect(style.pair(dark: true) == style.dark)
        style.sameInBoth = true
        #expect(style.pair(dark: true) == style.light)
    }

    @Test func gradientTakesAnOptionalMiddleColor() throws {
        var style = MenuBarTintStyle()
        style.kind = .gradient
        #expect(style.colors(dark: false) == [style.light.start, style.light.end])
        style.direction = .rightToLeft
        #expect(style.colors(dark: false) == [style.light.end, style.light.start])
        style.direction = .center
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
        // The old Middle color switch loads as Center (spec MB-15).
        var middle = MenuBarTintStyle()
        middle.kind = .gradient
        middle.usesMiddle = true
        #expect(middle.migrated().direction == .center)
        #expect(middle.migrated().colors(dark: false).count == 3)
    }
}

@Suite struct MiddleStopTests {
    @Test func snapsNearTheMarks() {
        #expect(MenuBarTintStyle.snapped(0.52) == 0.5)
        #expect(MenuBarTintStyle.snapped(0.31) == 1.0 / 3)
        #expect(MenuBarTintStyle.snapped(0.69) == 2.0 / 3)
        #expect(MenuBarTintStyle.snapped(0.42) == 0.42)
        #expect(MenuBarTintStyle.snapped(0.02) == 0.1)
    }

    @Test func middleStandsWhereSet() {
        var style = MenuBarTintStyle()
        style.kind = .gradient
        style.direction = .center
        #expect(style.stops(dark: false).map(\.location) == [0, 0.5, 1])
        style.middleStop = 0.25
        #expect(style.stops(dark: false).map(\.location) == [0, 0.25, 1])
        style.direction = .horizontal
        #expect(style.stops(dark: false).map(\.location) == [0, 1])
    }
}
