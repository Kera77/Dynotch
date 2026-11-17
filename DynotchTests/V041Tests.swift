import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// v0.41: the module strip (spec MS-1…MS-4) and the smart opening (spec SO-1…SO-4).
@MainActor
struct V041Tests {
    @Test func theFirstRuleThatAppliesWins() {
        var context = SmartContext()
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: []) == nil)
        context.usage = 95
        context.battery = "mouse"
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: [])?.feature == .battery)
        context.meeting = "m1"
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: [])?.feature == .calendar)
        // A rule turned off is skipped; an event used once is skipped too.
        #expect(SmartOpening.choose(context, isOn: { $0 != .meeting }, used: [])?.feature == .battery)
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: ["meeting:m1", "battery:mouse"])?.feature == .claudeUsage)
        context.usage = 80
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: ["meeting:m1", "battery:mouse"]) == nil)
    }

    @Test func remindersDueSoonCount() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        func item(_ id: String, in minutes: Double?, hasTime: Bool = true) -> ReminderItem {
            ReminderItem(
                id: id, title: id, listID: "l", due: minutes.map { now.addingTimeInterval($0 * 60) }, dueHasTime: hasTime,
                priority: 0, isCompleted: false, created: nil
            )
        }
        #expect(SmartOpening.dueReminder(in: [item("later", in: 60), item("soon", in: 10)], now: now)?.id == "soon")
        #expect(SmartOpening.dueReminder(in: [item("overdue", in: -30)], now: now)?.id == "overdue")
        #expect(SmartOpening.dueReminder(in: [item("day", in: 5, hasTime: false), item("none", in: nil)], now: now) == nil)
    }

    @Test func copiedCalculations() {
        #expect(SmartOpening.calculation(in: " 1200*1.27 \n") == "1200*1.27")
        #expect(SmartOpening.calculation(in: "42") == "42")
        #expect(SmartOpening.calculation(in: "hello world") == nil)
        #expect(SmartOpening.calculation(in: "1+1\n2+2") == nil)
    }

    @Test func theStripSitsCentredUnderTheNotch() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663, auxiliaryRightWidth: 664, menuBarHeight: 32
        )
        let strip = geometry.moduleStripRect(count: 5)
        #expect(abs(strip.midX - geometry.notchRect.midX) < 0.001)
        #expect(abs(strip.maxY - (geometry.notchRect.minY - NotchGeometry.stripGap)) < 0.001)
        #expect(abs(strip.width - (5 * NotchGeometry.stripIconSize + 4 * NotchGeometry.stripSpacing)) < 0.001)
    }

    @Test func stripDefaults() {
        let name = "V041Tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: defaults)
        #expect(settings.moduleStrip)
        #expect(abs(settings.moduleStripDelay - 0.3) < 0.001)
        #expect(abs(settings.moduleStripBand - 0.125) < 0.001)
        #expect(SmartRule.allCases.allSatisfy(settings.isSmartRuleOn))
        settings.setSmartRule(.usage, enabled: false)
        #expect(!AppSettings(defaults: defaults).isSmartRuleOn(.usage))
    }
}
