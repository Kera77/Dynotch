import AppKit
import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

struct ScreenshotTests {
    private func defaults() -> UserDefaults {
        let name = "screenshot-tests-\(UUID().uuidString)"
        return UserDefaults(suiteName: name) ?? .standard
    }

    @Test func eachPressStepsToTheNextModeRoundAndRound() {
        let modes: [CaptureMode] = [.area, .window, .screen]
        #expect(ScreenshotService.next(after: nil, in: modes) == .area)
        #expect(ScreenshotService.next(after: .area, in: modes) == .window)
        #expect(ScreenshotService.next(after: .screen, in: modes) == .area)
        #expect(ScreenshotService.next(after: .recording, in: modes) == .area)
        #expect(ScreenshotService.next(after: nil, in: []) == nil)
    }

    @Test @MainActor func theModesCanBeReorderedAndTurnedOff() {
        let settings = ScreenshotSettings(defaults: defaults())
        #expect(settings.shortcut == ScreenshotSettings.defaultShortcut)
        #expect(settings.modes == CaptureMode.allCases)
        settings.move(.screen, to: .area)
        #expect(settings.modes.prefix(2) == [.screen, .area])
        settings.setOn(.window, false)
        #expect(!settings.modes.contains(.window))
        // The last mode stays on.
        for mode in CaptureMode.allCases { settings.setOn(mode, false) }
        #expect(settings.modes.count == 1)
        settings.setOn(EditorTool.pixelate, false)
        #expect(!settings.tools.contains(.pixelate))
        #expect(ScreenshotSettings.normalized([.recording, .recording]).first == .recording)
        #expect(ScreenshotSettings.normalized([.recording]).count == CaptureMode.allCases.count)
    }

    @Test func filesAreNamedLikeMacOSNamesThem() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Budapest"))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 17, minute: 5, second: 9)))
        #expect(ScreenshotFiles.name(prefix: "Screenshot", date: date, ext: "png", calendar: calendar)
            == "Screenshot 2026-11-18 at 17.05.09.png")
    }

    @Test func theTrayListsTheTenNewestShots() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("shots-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for index in 0..<12 {
            let file = folder.appendingPathComponent("Shot \(index).png")
            try Data([1]).write(to: file)
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: Double(1000 + index))], ofItemAtPath: file.path
            )
        }
        try Data([1]).write(to: folder.appendingPathComponent("notes.txt"))
        let recent = ScreenshotFiles.recent(10, in: folder)
        #expect(recent.count == 10)
        #expect(recent.first?.lastPathComponent == "Shot 11.png")
        #expect(!recent.contains { $0.pathExtension == "txt" })
    }

    @Test func scrollingFindsHowFarThePageMoved() {
        // A page of varied rows; the next frame shows it 37 rows further down.
        let page = (0..<400).map { Double(($0 * 37) % 251) }
        let previous = Array(page[0..<200])
        let next = Array(page[37..<237])
        #expect(ScrollStitcher.offset(previous: previous, next: next) == 37)
        #expect(ScrollStitcher.offset(previous: previous, next: previous) == 0)
        // Something else entirely: no match, the frame is skipped.
        let other = (0..<200).map { Double(($0 * 91 + 13) % 199) }
        #expect(ScrollStitcher.offset(previous: previous, next: other) == nil)
    }

    @Test func arrowsGetTheirHeadAtTheTip() {
        let head = Annotation.arrowHead(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0), length: 10)
        #expect(head.0.x < 100 && head.1.x < 100)
        #expect(head.0.y * head.1.y < 0)
        #expect(Annotation.rect(CGPoint(x: 10, y: 50), CGPoint(x: 2, y: 5)) == CGRect(x: 2, y: 5, width: 8, height: 45))
    }

    @Test @MainActor func theEditorDrawsUndoesAndCrops() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("edit-\(UUID().uuidString).png")
        let context = try #require(CGContext(
            data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        let image = try #require(context.makeImage())
        #expect(ScreenshotFiles.save(image, to: url))
        let editor = try #require(ScreenshotEditor(url: url, tools: EditorTool.allCases))
        // Never the real clipboard: a test once replaced the owner's copy with its blue picture.
        editor.pasteboard = NSPasteboard(name: NSPasteboard.Name("WingmateTests"))
        editor.tool = .counter
        editor.endDrag(at: CGPoint(x: 20, y: 20), start: CGPoint(x: 20, y: 20))
        editor.endDrag(at: CGPoint(x: 60, y: 20), start: CGPoint(x: 60, y: 20))
        #expect(editor.nextCounter == 3)
        editor.undo()
        #expect(editor.annotations.count == 1)
        editor.redo()
        #expect(editor.annotations.count == 2)
        editor.tool = .crop
        editor.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 60))
        editor.endDrag(at: CGPoint(x: 110, y: 60), start: CGPoint(x: 10, y: 10))
        #expect(editor.crop == CGRect(x: 10, y: 10, width: 100, height: 50))
        #expect(editor.save())
        let saved = try #require(ScreenshotEditor(url: url, tools: EditorTool.allCases))
        #expect(saved.image.width == 100 && saved.image.height == 50)
    }

    private func image(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return try #require(context.makeImage())
    }

    @Test func aPartIsCutOnWholePixels() throws {
        let full = try image(width: 200, height: 100)
        // Half points on a 1x display land on whole pixels.
        let part = try #require(ScreenCapture.crop(full, to: CGRect(x: 10.4, y: 5.6, width: 50.2, height: 20.4), scale: 1))
        #expect(part.width == 50)
        #expect(part.height == 20)
        let retina = try #require(ScreenCapture.crop(full, to: CGRect(x: 10, y: 5, width: 30, height: 20), scale: 2))
        #expect(retina.width == 60)
        #expect(retina.height == 40)
        // Outside the display it is clipped, never bigger than the display.
        let edge = try #require(ScreenCapture.crop(full, to: CGRect(x: 190, y: 0, width: 50, height: 10), scale: 1))
        #expect(edge.width == 10)
        #expect(ScreenCapture.crop(full, to: CGRect(x: 300, y: 0, width: 5, height: 5), scale: 1) == nil)
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
