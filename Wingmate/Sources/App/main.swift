import AppKit

MainActor.assumeIsolated {
    // Before anything reads settings or files under the new name (spec RN-2).
    RenameMigration.runIfNeeded()
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
