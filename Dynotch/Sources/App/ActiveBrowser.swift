import AppKit

/// The browser in use right now (spec E-2f): web pages Dynotch opens (meeting links, Gmail,
/// websites, Google Chat) go to it, not to the default browser. In order: the frontmost app if it
/// is a browser, the browser that was active last and still runs, any running browser, the
/// default browser.
@MainActor
final class ActiveBrowser {
    static let shared = ActiveBrowser()

    private var lastBundleID: String?
    private var observer: NSObjectProtocol?

    /// Starts remembering which browser was active last.
    func start() {
        guard observer == nil else { return }
        if let front = NSWorkspace.shared.frontmostApplication, Self.isBrowser(front) { lastBundleID = front.bundleIdentifier }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app.flatMap { Self.isBrowser($0) ? $0.bundleIdentifier : nil }
            MainActor.assumeIsolated {
                if let bundleID { self?.lastBundleID = bundleID }
            }
        }
    }

    /// The browser app to open web pages with.
    func url() -> URL? {
        let workspace = NSWorkspace.shared
        if let front = workspace.frontmostApplication, Self.isBrowser(front), let url = front.bundleURL { return url }
        let running = workspace.runningApplications.filter(Self.isBrowser)
        if let lastBundleID, let last = running.first(where: { $0.bundleIdentifier == lastBundleID }), let url = last.bundleURL {
            return url
        }
        if let any = running.first(where: { $0.activationPolicy == .regular }), let url = any.bundleURL { return url }
        return Self.probe.flatMap { workspace.urlForApplication(toOpen: $0) }
    }

    /// The browser's bundle identifier (see `url()`).
    func bundleID() -> String? {
        url().flatMap { Bundle(url: $0)?.bundleIdentifier }
    }

    /// Opens a web page in the browser in use.
    func open(_ page: URL, activates: Bool = true, completion: (@Sendable (NSRunningApplication?, (any Error)?) -> Void)? = nil) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        guard let browser = url() else {
            NSWorkspace.shared.open(page)
            return
        }
        NSWorkspace.shared.open([page], withApplicationAt: browser, configuration: configuration, completionHandler: completion)
    }

    nonisolated private static let probe = URL(string: "https://example.com")

    /// A browser: a known one, or any app that can open web pages (installed web apps excluded).
    nonisolated static func isBrowser(_ app: NSRunningApplication) -> Bool {
        guard let bundleID = app.bundleIdentifier else { return false }
        return isBrowser(bundleID: bundleID)
    }

    nonisolated static func isBrowser(bundleID: String) -> Bool {
        let lowered = WebNotificationSource.owningApp(bundleID).lowercased()
        if WebNotificationSource.isWebApp(lowered) || lowered == "com.apple.safari.webapp" { return false }
        if WebNotificationSource.browserIdentifiers.contains(lowered) { return true }
        guard let probe else { return false }
        return NSWorkspace.shared.urlsForApplications(toOpen: probe)
            .compactMap { Bundle(url: $0)?.bundleIdentifier?.lowercased() }
            .contains(lowered)
    }
}
