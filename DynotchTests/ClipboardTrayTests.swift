@testable import Dynotch
import Foundation
import Testing

/// The clipboard manager (spec CB-1…CB-7) and the file tray (spec FT-1…FT-7).
@MainActor
struct ClipboardTrayTests {
    private func temporaryFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClipboardTrayTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func defaults() -> UserDefaults {
        let name = "ClipboardTrayTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func newestFirstWithoutDuplicatesAndLimited() {
        var items: [ClipItem] = []
        for text in ["a", "b", "a", "c"] {
            items = ClipboardRules.adding(ClipItem(kind: .text, text: text), to: items, limit: 2)
        }
        #expect(items.map(\.text) == ["c", "a"])
    }

    @Test func passwordManagersAreSkipped() {
        #expect(ClipboardRules.isSkipped(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
        #expect(!ClipboardRules.isSkipped(types: ["public.utf8-plain-text"]))
    }

    @Test func savedItemsAndDefaults() {
        let store = ClipboardStore(defaults: defaults(), folder: temporaryFolder())
        #expect(store.historyShortcut == .optionV)
        #expect(store.savedShortcut == .optionShiftV)
        #expect(store.limit == 25)
        store.addSaved(text: "  IBAN 123  ")
        #expect(store.saved.map(\.text) == ["IBAN 123"])
        let item = ClipItem(kind: .text, text: "IBAN 123")
        #expect(store.isSaved(item))
        store.toggleSaved(item)
        #expect(store.saved.isEmpty)
    }

    @Test func savedItemsAreKeptOnDisk() {
        let folder = temporaryFolder()
        let settings = defaults()
        ClipboardStore(defaults: settings, folder: folder).addSaved(text: "Address")
        #expect(ClipboardStore(defaults: settings, folder: folder).saved.map(\.text) == ["Address"])
    }

    @Test func trayKeepsReferencesAndStepsThroughFolders() throws {
        let home = temporaryFolder()
        let store = TrayStore(defaults: defaults(), folder: home.appendingPathComponent("Tray"))
        // A file in a temporary place is copied into the tray folder first.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("tray-\(UUID().uuidString).txt")
        try Data("x".utf8).write(to: file)
        store.add([file, file])
        #expect(store.items.count == 1)
        let kept = try #require(store.trayFiles.first?.url)
        // /var and /private/var are the same folder.
        #expect(kept.resolvingSymlinksInPath().path.hasPrefix(home.resolvingSymlinksInPath().path))
        #expect(store.step(by: 1) == false)
        #expect(store.step(by: -1) == false)
        store.remove(store.items[0])
        #expect(store.items.isEmpty)
    }

    @Test func freeNamesDoNotOverwrite() throws {
        let folder = temporaryFolder()
        try Data().write(to: folder.appendingPathComponent("a.txt"))
        #expect(TrayStore.freeName(for: "a.txt", in: folder).lastPathComponent == "a 2.txt")
        #expect(TrayStore.freeName(for: "b.txt", in: folder).lastPathComponent == "b.txt")
        #expect(TrayStore.isTemporary(FileManager.default.temporaryDirectory.appendingPathComponent("x")))
        #expect(!TrayStore.isTemporary(URL(fileURLWithPath: "/Users/someone/Documents/x.pdf")))
    }
}
