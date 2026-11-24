@testable import Dynotch
import Foundation
import Testing

/// v0.104: downloads in the tray (FT-15).
@MainActor
struct V104Tests {
    @Test func downloadsLeaveOnTheirOwnSchedule() throws {
        let name = "V104Tests-\(UUID().uuidString)"
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
