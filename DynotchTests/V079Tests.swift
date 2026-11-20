@testable import Dynotch
import Foundation
import Testing

/// v0.79: download notice, notification deleted from the wings, strip hover setting.
@MainActor
struct V079Tests {
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

    @Test func stripHoverSettingIsKept() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let settings = AppSettings(defaults: defaults)
        #expect(!settings.moduleStripHover)
        #expect(settings.moduleStripHoverDelay == 0.5)
        settings.moduleStripHover = true
        settings.moduleStripHoverDelay = 0.8
        let again = AppSettings(defaults: defaults)
        #expect(again.moduleStripHover)
        #expect(again.moduleStripHoverDelay == 0.8)
    }
}
