@testable import Dynotch
import Foundation
import Testing

@MainActor
/// The smart opening's code, download and morning rules (spec SO-5…SO-8).
struct SmartOpeningRulesTests {
    @Test func codesAreFourToEightDigits() {
        #expect(SmartOpening.code(in: "123456") == "123456")
        #expect(SmartOpening.code(in: " 123 456\n") == "123 456")
        #expect(SmartOpening.code(in: "123-456") == "123-456")
        #expect(SmartOpening.code(in: "123") == nil)
        #expect(SmartOpening.code(in: "123456789") == nil)
        #expect(SmartOpening.code(in: "12 34 56") == nil)
        #expect(SmartOpening.code(in: "12+34") == nil)
        #expect(SmartOpening.code(in: "AB1234") == nil)
    }

    @Test func aCodeIsNotACalculation() {
        #expect(SmartOpening.calculation(in: "123456") == nil)
        #expect(SmartOpening.calculation(in: "12*3") == "12*3")
    }

    @Test func morningIsFiveToNoon() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 0)) ?? Date()
        #expect(SmartOpening.morningKey(now: day.addingTimeInterval(4 * 3600), calendar: calendar) == nil)
        #expect(SmartOpening.morningKey(now: day.addingTimeInterval(7 * 3600), calendar: calendar) == "2026-11-19")
        #expect(SmartOpening.morningKey(now: day.addingTimeInterval(12 * 3600), calendar: calendar) == nil)
    }

    @Test func theNewRulesKeepTheirPlace() {
        var context = SmartContext(battery: "mouse")
        context.code = ("123456", 7)
        context.download = URL(fileURLWithPath: "/tmp/a.zip")
        context.morning = "2026-11-19"
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: [])?.feature == .clipboard)
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: ["code:7"])?.feature == .tray)
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: ["code:7", "download:/tmp/a.zip"])?.feature == .battery)
        let used: Set<String> = ["code:7", "download:/tmp/a.zip", "battery:mouse"]
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: used)?.feature == .calendar)
        #expect(SmartOpening.choose(context, isOn: { $0 != .morning }, used: used) == nil)
    }

    @Test func onlyFinishedRecentDownloadsCount() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let now = Date()
        let old = folder.appendingPathComponent("old.pdf")
        let partial = folder.appendingPathComponent("big.zip.crdownload")
        let fresh = folder.appendingPathComponent("fresh.zip")
        for url in [old, partial, fresh] { try Data("x".utf8).write(to: url) }
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-600)], ofItemAtPath: old.path)
        #expect(SmartOpening.recentDownload(now: now, folder: folder)?.lastPathComponent == "fresh.zip")
        try FileManager.default.removeItem(at: fresh)
        #expect(SmartOpening.recentDownload(now: now, folder: folder) == nil)
    }
}
