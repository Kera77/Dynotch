import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

@MainActor
struct BadgeTests {
    private let notchRect = CGRect(x: 663.5, y: 950, width: 185, height: 32)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeDefaults() -> UserDefaults {
        let name = "BadgeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func app(_ id: String) -> InstalledApp {
        InstalledApp(bundleID: id, name: id, path: "/Applications/\(id).app")
    }

    // MARK: - New notifications (spec B-5)

    @Test func aBadgeIsNewWhenItAppearsOrGrows() {
        #expect(BadgeTracker.isNew(previous: nil, current: "1"))
        #expect(BadgeTracker.isNew(previous: "", current: "3"))
        #expect(BadgeTracker.isNew(previous: "2", current: "3"))
        #expect(!BadgeTracker.isNew(previous: "3", current: "3"))
        #expect(!BadgeTracker.isNew(previous: "3", current: "2"))
        #expect(!BadgeTracker.isNew(previous: "3", current: ""))
        #expect(BadgeTracker.isNew(previous: "•", current: "!"))
    }

    @Test func pulsingLastsFiveMinutesAndRestarts() {
        var pulses = BadgeTracker.pulses([:], previous: [:], current: ["a": "1"], now: now)
        #expect(pulses["a"] == now)
        #expect(BadgeTracker.isPulsing(since: pulses["a"], now: now.addingTimeInterval(299)))
        #expect(!BadgeTracker.isPulsing(since: pulses["a"], now: now.addingTimeInterval(300)))

        // Unchanged: keeps the start; a further notification restarts it.
        let later = now.addingTimeInterval(120)
        pulses = BadgeTracker.pulses(pulses, previous: ["a": "1"], current: ["a": "1"], now: later)
        #expect(pulses["a"] == now)
        pulses = BadgeTracker.pulses(pulses, previous: ["a": "1"], current: ["a": "2"], now: later)
        #expect(pulses["a"] == later)

        // Read: the badge is gone, so is the pulse.
        pulses = BadgeTracker.pulses(pulses, previous: ["a": "2"], current: [:], now: later)
        #expect(pulses.isEmpty)
    }

    @Test func textIsShort() {
        #expect(BadgeTracker.displayText("7") == "7")
        #expect(BadgeTracker.displayText(" 42 ") == "42")
        #expect(BadgeTracker.displayText("1234") == "99+")
        #expect(BadgeTracker.displayText("hello") == "hel")
        #expect(BadgeItem.width(text: "12") > BadgeItem.width(text: "1"))
    }

    // MARK: - Service

    @Test func onlyEnabledAppsWithABadgeAreVisible() {
        let service = BadgeService(defaults: makeDefaults())
        service.add(app("a"))
        service.add(app("b"))
        service.add(app("c"))
        service.setEnabled("b", false)
        service.apply(["a": "2", "b": "5"], now: now)
        #expect(service.visible.map(\.id) == ["a"])
        // What was there at the first look is not new.
        #expect(service.visible.first?.pulseStart == nil)

        service.apply(["a": "3", "c": "1"], now: now)
        #expect(service.visible.map(\.id) == ["a", "c"])
        #expect(service.visible.allSatisfy { $0.pulseStart == now })

        service.apply([:], now: now)
        #expect(service.visible.isEmpty)
    }

    @Test func choicesArePersisted() {
        let defaults = makeDefaults()
        let service = BadgeService(defaults: defaults)
        service.add(app("com.apple.mail"))
        service.add(app("x"))
        service.add(app("x"))
        service.setIcon("x", .symbol("bell.fill"))
        service.move(from: IndexSet(integer: 1), to: 0)

        let reloaded = BadgeService(defaults: defaults)
        #expect(reloaded.apps.map(\.bundleID) == ["x", "com.apple.mail"])
        #expect(reloaded.apps.first?.icon == .symbol("bell.fill"))
        #expect(reloaded.apps.last?.icon == .symbol("envelope.fill"))

        reloaded.remove("x")
        #expect(BadgeService(defaults: defaults).apps.map(\.bundleID) == ["com.apple.mail"])
    }

    @Test func movingAVisibleBadgeKeepsHiddenAppsInPlace() {
        let service = BadgeService(defaults: makeDefaults())
        ["a", "b", "c", "d"].forEach { service.add(app($0)) }
        service.apply(["a": "1", "c": "1", "d": "1"], now: now)
        service.moveVisible("d", toVisibleIndex: 0)
        #expect(service.apps.map(\.bundleID) == ["d", "b", "a", "c"])
        #expect(service.visible.map(\.id) == ["d", "a", "c"])
    }

    @Test func suggestedIcons() {
        #expect(BadgePreset.suggestedIcon(bundleID: "com.apple.mail", name: "Mail") == .symbol("envelope.fill"))
        let beeper = BadgePreset.suggestedIcon(bundleID: "com.automattic.beeper.desktop", name: "Beeper")
        #expect(beeper == .symbol(BrandGlyph.beeper.rawValue))
        let claude = BadgePreset.suggestedIcon(bundleID: "com.anthropic.claudefordesktop", name: "Claude")
        #expect(claude == .symbol(BadgePreset.claudeSymbol))
        #expect(BadgePreset.suggestedIcon(bundleID: "com.apple.finder", name: "Finder") == .app)
    }

    @Test func brandMarksReplaceGenericGlyphsOnce() {
        let chat = BadgeApp(bundleID: "com.google.Chrome.app.x", name: "Google Chat", isEnabled: true, icon: .symbol("bubble.left.fill"))
        #expect(BadgeTracker.upgradedIcon(for: chat) == .symbol(BrandGlyph.googleChat.rawValue))
        let gmail = BadgeApp(bundleID: "x", name: "Gmail", isEnabled: true, icon: .symbol("envelope.fill"))
        #expect(BadgeTracker.upgradedIcon(for: gmail) == .symbol(BrandGlyph.gmail.rawValue))
        // A choice the user made, or an app without its own mark, stays.
        let custom = BadgeApp(bundleID: "x", name: "Gmail", isEnabled: true, icon: .symbol("star.fill"))
        #expect(BadgeTracker.upgradedIcon(for: custom) == .symbol("star.fill"))
        let mail = BadgeApp(bundleID: "com.apple.mail", name: "Mail", isEnabled: true, icon: .symbol("envelope.fill"))
        #expect(BadgeTracker.upgradedIcon(for: mail) == .symbol("envelope.fill"))
        #expect(BadgePreset.all.contains { $0.symbol == BrandGlyph.beeper.rawValue })
        #expect(BrandGlyph.allCases.allSatisfy { !BrandGlyphShape(glyph: $0).path(in: CGRect(x: 0, y: 0, width: 16, height: 16)).isEmpty })
    }

    @Test func hoveringStopsThePulse() {
        let service = BadgeService(defaults: makeDefaults())
        service.add(app("a"))
        service.apply([:], now: now)
        service.apply(["a": "1"], now: now)
        #expect(service.visible.first?.pulseStart == now)
        service.acknowledge("a")
        #expect(service.visible.first?.pulseStart == nil)
        // The next notification starts it again.
        service.apply(["a": "2"], now: now)
        #expect(service.visible.first?.pulseStart == now)
    }

    // MARK: - Reordering (spec B-7)

    @Test func draggingFindsTheNewPlace() {
        let widths: [CGFloat] = [26, 40, 26]
        #expect(BadgeReorder.targetIndex(widths: widths, from: 0, offset: 0, spacing: 8) == 0)
        #expect(BadgeReorder.targetIndex(widths: widths, from: 0, offset: 45, spacing: 8) == 1)
        #expect(BadgeReorder.targetIndex(widths: widths, from: 0, offset: 200, spacing: 8) == 2)
        #expect(BadgeReorder.targetIndex(widths: widths, from: 2, offset: -200, spacing: 8) == 0)
        #expect(BadgeReorder.shift(of: 1, from: 0, target: 2, draggedWidth: 26, spacing: 8) == -34)
        #expect(BadgeReorder.shift(of: 0, from: 2, target: 0, draggedWidth: 26, spacing: 8) == 34)
        #expect(BadgeReorder.shift(of: 2, from: 0, target: 1, draggedWidth: 26, spacing: 8) == 0)
        #expect(BadgeReorder.moved(["a", "b", "c"], id: "c", to: 0) == ["c", "a", "b"])
    }

    // MARK: - Layout (spec B-4)

    @Test func badgesWidenOnlyTheLeftSide() {
        let plain = IndicatorLayout(count: 1)
        let layout = IndicatorLayout(slotWidths: [IndicatorLayout.slotWidth], badgeWidths: [26, 33])
        #expect(layout.rightWidth == plain.rightWidth)
        let extra = IndicatorLayout.separatorWidth + 26 + 33 + IndicatorLayout.badgeSpacing
        #expect(abs(layout.leftWidth - plain.leftWidth - extra) < 0.001)

        // Badges alone: no icons, no line, nothing on the right.
        let alone = IndicatorLayout(slotWidths: [], badgeWidths: [26])
        #expect(!alone.isEmpty)
        #expect(alone.rightWidth == 0)
        #expect(alone.leftWidth == 26 + 2 * IndicatorLayout.padding)
        let rect = alone.rect(notchRect: notchRect, labelHeight: nil)
        #expect(abs(rect.maxX - notchRect.maxX) < 0.001)
        #expect(abs(notchRect.minX - rect.minX - alone.leftWidth) < 0.001)
    }

    @Test func hoverTellsBadgesFromIcons() {
        let layout = IndicatorLayout(slotWidths: [IndicatorLayout.slotWidth], badgeWidths: [26, 33])
        let y = notchRect.midY
        for index in 0..<2 {
            let range = layout.badgeRange(index, notchRect: notchRect)
            let point = CGPoint(x: (range.lowerBound + range.upperBound) / 2, y: y)
            #expect(layout.badge(at: point, notchRect: notchRect) == index)
            #expect(layout.slot(at: point, notchRect: notchRect) == nil)
        }
        let icon = CGPoint(x: layout.iconCenter(notchRect: notchRect), y: y)
        #expect(layout.slot(at: icon, notchRect: notchRect) == 0)
        #expect(layout.badge(at: icon, notchRect: notchRect) == nil)
        #expect(layout.badge(at: CGPoint(x: notchRect.midX, y: y), notchRect: notchRect) == nil)
        #expect(layout.badge(at: CGPoint(x: icon.x, y: notchRect.minY - 20), notchRect: notchRect) == nil)
    }

    @Test func backgroundHelpersAreNotOfferedForBadges() {
        #expect(InstalledApps.isBackgroundOnly(["LSUIElement": true]))
        #expect(InstalledApps.isBackgroundOnly(["LSUIElement": "1"]))
        #expect(InstalledApps.isBackgroundOnly(["LSBackgroundOnly": NSNumber(value: 1)]))
        #expect(!InstalledApps.isBackgroundOnly(["LSUIElement": false]))
        #expect(!InstalledApps.isBackgroundOnly(["CFBundleName": "Mail"]))
        #expect(!InstalledApps.isBackgroundOnly(nil))
        #expect(InstalledApps.coreServicesAllowed.contains("com.apple.finder"))
    }

    @Test func chatBadgesOpenTheirTab() {
        let beeper = BadgeApp(bundleID: "com.automattic.beeper.desktop", name: "Beeper Desktop", isEnabled: true, icon: .app)
        let chat = BadgeApp(bundleID: "com.apple.Safari.WebApp.940A", name: "Google Chat", isEnabled: true, icon: .app)
        let mail = BadgeApp(bundleID: "com.apple.mail", name: "Mail", isEnabled: true, icon: .app)
        #expect(BadgeApp.chatTab(for: beeper) == .beeper)
        #expect(BadgeApp.chatTab(for: chat) == .googleChat)
        #expect(BadgeApp.chatTab(for: mail) == nil)
    }

    @Test func badgeListHeightFollowsItsNotificationsUpToFive() {
        func row(_ id: Int64, _ sender: String) -> BadgeNotificationRow {
            BadgeNotificationRow(id: id, sender: sender, detail: "m", date: Date())
        }
        #expect(IndicatorLayout.badgeDropdownHeight(rows: []) == 34)
        // Anna twice, Béla once: two name lines, three messages (spec B-10b).
        let rows = [row(1, "Anna"), row(2, "Béla"), row(3, "Anna")]
        #expect(BadgeNotificationRow.bySender(rows, limit: 5).map(\.sender) == ["Anna", "Béla"])
        #expect(BadgeNotificationRow.bySender(rows, limit: 5).first?.rows.map(\.id) == [1, 3])
        #expect(IndicatorLayout.badgeDropdownHeight(rows: rows) == CGFloat(8 + 2 * 20 + 3 * 18))
        let many = (0..<12).map { row(Int64($0), "Anna") }
        // All twelve are in the list; it stops growing at its limit and scrolls (spec B-10e).
        #expect(IndicatorLayout.badgeContentHeight(rows: many) == CGFloat(8 + 20 + 12 * 18))
        #expect(IndicatorLayout.badgeDropdownHeight(rows: many) == IndicatorLayout.badgeDropdownMaxHeight)
    }

    @Test func highlightedNetworksTakeTheirShareOfBeepersBadge() {
        #expect(BeeperNetworkBadge.remainder("7", minus: 3) == "4")
        #expect(BeeperNetworkBadge.remainder("3", minus: 3) == nil)
        #expect(BeeperNetworkBadge.remainder("5", minus: 0) == "5")
        let beeper = BadgeApp(bundleID: "com.automattic.beeper.desktop", name: "Beeper", isEnabled: true, icon: .app)
        let synced = BeeperNetworkBadge.synced([beeper, BeeperNetworkBadge.app("WhatsApp")], networks: ["Google Chat"])
        #expect(synced.map(\.bundleID) == [beeper.bundleID, "beeper-network:Google Chat"])
        #expect(BadgeApp.chatTab(for: BeeperNetworkBadge.app("Google Chat")) == .network("Google Chat"))
    }

    @Test func aHiddenBadgeComesBackAfterItsTime() {
        let hour = BadgeHide.make(.hour, label: "2", now: now)
        let hidden = ["a": hour, "b": BadgeHide.always]
        #expect(BadgeHide.remaining(hidden, labels: ["a": "2", "b": "1"], now: now.addingTimeInterval(1800)).count == 2)
        let later = BadgeHide.remaining(hidden, labels: ["a": "2", "b": "1"], now: now.addingTimeInterval(3601))
        #expect(later["a"] == nil)
        #expect(later["b"] == .always)
    }

    @Test func untilNewEndsWithANewMessageOrNoBadge() {
        let hidden = ["a": BadgeHide.make(.untilNew, label: "3", now: now)]
        // The same or fewer unread: still hidden.
        #expect(BadgeHide.remaining(hidden, labels: ["a": "3"], now: now).count == 1)
        #expect(BadgeHide.remaining(hidden, labels: ["a": "2"], now: now).count == 1)
        // A new one, or all read (the next one shows).
        #expect(BadgeHide.remaining(hidden, labels: ["a": "4"], now: now).isEmpty)
        #expect(BadgeHide.remaining(hidden, labels: [:], now: now).isEmpty)
    }

    @MainActor @Test func hiddenBadgesStayHiddenAfterARestart() {
        let defaults = UserDefaults(suiteName: "BadgeTests-\(UUID().uuidString)") ?? .standard
        let service = BadgeService(defaults: defaults)
        service.hide("com.example.app", .always)
        #expect(BadgeService(defaults: defaults).hidden["com.example.app"] == .always)
        service.unhide("com.example.app")
        #expect(BadgeService(defaults: defaults).hidden.isEmpty)
    }
}
