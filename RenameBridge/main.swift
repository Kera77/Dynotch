import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = BridgeDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
