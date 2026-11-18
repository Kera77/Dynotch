@testable import Dynotch
import Foundation
import Testing

/// v0.59: list or tiles per tray tab (spec FT-11b).
struct V059Tests {
    @MainActor @Test func trayListModeIsKeptPerTab() {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("V059Tray-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "V059Tray-\(UUID().uuidString)") ?? .standard
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
}
