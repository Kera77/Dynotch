import CoreGraphics
import Foundation
import Testing
@testable import Wingmate

/// The file tray: its folder, tabs, drag-out and downloads (spec FT-4c, FT-11b, FT-15).
@MainActor
struct TrayTests {
    @MainActor @Test func trayKnowsItsOwnFolder() {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TrayTests-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "TrayTests-\(UUID().uuidString)") ?? .standard
        #expect(TrayStore(defaults: defaults, folder: folder).folder == folder)
    }

    @Test func dragOutNamesAFreeCopy() {
        let folder = URL(fileURLWithPath: "/tmp/x")
        let taken: Set<String> = ["/tmp/x/report.pdf", "/tmp/x/report (1).pdf", "/tmp/x/notes"]
        let exists: (URL) -> Bool = { taken.contains($0.path) }
        #expect(TrayFileTransfer.freeURL(for: "report.pdf", in: folder, exists: exists).lastPathComponent == "report (2).pdf")
        #expect(TrayFileTransfer.freeURL(for: "notes", in: folder, exists: exists).lastPathComponent == "notes (1)")
        #expect(TrayFileTransfer.freeURL(for: "new.txt", in: folder, exists: exists).lastPathComponent == "new.txt")
    }

    @Test func dragOutMovesOrCopies() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("TrayTests-\(UUID().uuidString)")
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

    @MainActor @Test func trayListModeIsKeptPerTab() {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TrayTests-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "TrayTests-\(UUID().uuidString)") ?? .standard
        // The old shared choice carries over to every tab that has none yet.
        defaults.set(true, forKey: "trayShowsList")
        let store = TrayStore(defaults: defaults, folder: folder)
        #expect(store.showsList)
        store.showsList = false
        store.selectedFolder = TrayStore.screenshotsID
        #expect(store.showsList)
        store.showsList = false
        store.selectedFolder = nil
        store.showsList = true
        let reopened = TrayStore(defaults: defaults, folder: folder)
        #expect(reopened.showsList)
        reopened.selectedFolder = TrayStore.screenshotsID
        #expect(!reopened.showsList)
    }

    @MainActor @Test func trayAndScreenshotsKeepTheirColour() {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TrayTests-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "TrayTests-\(UUID().uuidString)") ?? .standard
        let store = TrayStore(defaults: defaults, folder: folder)
        #expect(store.colour(ofFixed: "tray") == 2)
        #expect(store.colour(ofFixed: "screenshots") == 3)
        store.setColour(6, ofFixed: "screenshots")
        let reopened = TrayStore(defaults: defaults, folder: folder)
        #expect(reopened.colour(ofFixed: "screenshots") == 6)
        #expect(reopened.colour(ofFixed: "tray") == 2)
    }

    @Test func downloadNoticeCountsOnlyJustFinishedFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let now = Date()
        let old = folder.appendingPathComponent("old.pdf")
        let partial = folder.appendingPathComponent("big.zip.crdownload")
        let fresh = folder.appendingPathComponent("fresh.zip")
        for url in [old, partial, fresh] { try Data("x".utf8).write(to: url) }
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-60)], ofItemAtPath: old.path)
        let found = DownloadWatcher.finishedFiles(in: folder, now: now).map(\.url.lastPathComponent)
        #expect(found == ["fresh.zip"])
    }

    @Test func downloadNoticeGoesByItselfAndYieldsToOthers() {
        let notices = NoticeService()
        let file = URL(fileURLWithPath: "/tmp/a.zip")
        notices.showDownload(file)
        #expect(notices.notice?.download == file)
        #expect(notices.notice?.source == "Downloads")
        notices.show(StickyNotice(title: "Claude finished", detail: "app", date: Date()))
        notices.showDownload(file)
        #expect(notices.notice?.download == nil)
    }

    @Test func downloadsLeaveOnTheirOwnSchedule() throws {
        let name = "TrayTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let store = TrayStore(defaults: defaults, folder: home.appendingPathComponent("Tray"))
        #expect(store.keepsDownloads)
        #expect(store.downloadRetentionDays == 3)
        let lasting = home.appendingPathComponent("Lasting")
        try FileManager.default.createDirectory(at: lasting, withIntermediateDirectories: true)
        let dropped = lasting.appendingPathComponent("dropped.txt")
        let downloaded = lasting.appendingPathComponent("downloaded.txt")
        try Data("x".utf8).write(to: dropped)
        try Data("y".utf8).write(to: downloaded)
        store.add([dropped])
        store.addDownload(downloaded)
        #expect(store.items.first?.download == true)
        #expect(store.items.count == 2)
        // Four days later the download is gone from the tray, the dropped file (never) stays.
        store.dropExpired(now: Date().addingTimeInterval(4 * 86_400))
        #expect(store.items.map(\.name) == ["dropped.txt"])
        #expect(FileManager.default.fileExists(atPath: downloaded.path))
        // Switched off: downloads stay out.
        store.keepsDownloads = false
        store.addDownload(downloaded)
        #expect(store.items.count == 1)
    }
}
