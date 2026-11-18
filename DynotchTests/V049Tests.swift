@testable import Dynotch
import Foundation
import SwiftUI
import Testing

/// Tray drag-out names, the calendar wall, hover drop-downs, blur, the inline clipboard.
struct V049Tests {
    @Test func dragOutNamesAFreeCopy() {
        let folder = URL(fileURLWithPath: "/tmp/x")
        let taken: Set<String> = ["/tmp/x/report.pdf", "/tmp/x/report (1).pdf", "/tmp/x/notes"]
        let exists: (URL) -> Bool = { taken.contains($0.path) }
        #expect(TrayFileTransfer.freeURL(for: "report.pdf", in: folder, exists: exists).lastPathComponent == "report (2).pdf")
        #expect(TrayFileTransfer.freeURL(for: "notes", in: folder, exists: exists).lastPathComponent == "notes (1)")
        #expect(TrayFileTransfer.freeURL(for: "new.txt", in: folder, exists: exists).lastPathComponent == "new.txt")
    }

    @Test func dragOutMovesOrCopies() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("V049-\(UUID().uuidString)")
        let source = base.appendingPathComponent("from")
        let target = base.appendingPathComponent("to")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = source.appendingPathComponent("a.txt")
        try Data("x".utf8).write(to: file)
        try Data("y".utf8).write(to: target.appendingPathComponent("a.txt"))

        let copied = try TrayFileTransfer.transfer(file, into: target, move: false)
        #expect(copied.lastPathComponent == "a (1).txt")
        #expect(FileManager.default.fileExists(atPath: file.path))
        let moved = try TrayFileTransfer.transfer(file, into: target, move: true)
        #expect(moved.lastPathComponent == "a (2).txt")
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func calendarStopsAtTwoWeeks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18)))
        let far = try #require(calendar.date(byAdding: .day, value: 20, to: today))
        let near = try #require(calendar.date(byAdding: .day, value: -3, to: today))
        #expect(DayStripView.clamped(far, around: today, calendar: calendar) == calendar.date(byAdding: .day, value: 14, to: today))
        #expect(DayStripView.clamped(near, around: today, calendar: calendar) == near)
    }

    @Test func hoverDropDownClosesOnlyWhenOpenedByHoverAndLeft() {
        var intent = HoverIntent(openedByHover: true, overButton: false, overPopover: false)
        #expect(intent.shouldClose)
        intent.overPopover = true
        #expect(!intent.shouldClose)
        intent = HoverIntent(openedByHover: false, overButton: false, overPopover: false)
        #expect(!intent.shouldClose)
    }

    @Test func blurFollowsTheDesign() {
        #expect(DesignBackground<Rectangle>.blurOpacity(glass: false, isOpen: true, openOpacity: 1) == 0)
        #expect(abs(DesignBackground<Rectangle>.blurOpacity(glass: false, isOpen: true, openOpacity: 0.4) - 0.55) < 0.0001)
        #expect(DesignBackground<Rectangle>.blurOpacity(glass: true, isOpen: true, openOpacity: 1) > 0.5)
        #expect(DesignBackground<Rectangle>.blurOpacity(glass: true, isOpen: false, openOpacity: 1) == 0)
    }
}
