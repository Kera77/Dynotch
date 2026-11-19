import AppKit
import Combine

/// The unread messages of the accounts set up in Apple Mail, read through Apple Events, only
/// read, never marked (spec GM-1…GM-12).
@MainActor
final class MailService: ObservableObject {
    enum State: Equatable {
        case off
        case notRunning
        case noAccess
        case noAccounts
        case failed
        case reading
    }

    nonisolated static let mailBundleID = "com.apple.mail"
    static let intervalRange = 30...300

    @Published private(set) var state: State = .off
    /// Every account Mail has, the chosen ones with their unread messages.
    @Published private(set) var accounts: [MailAccount] = []
    @Published private(set) var lastRead: Date?

    /// The accounts shown in the notch, by name; nil: the Gmail ones (spec GM-3).
    @Published var chosen: Set<String>? {
        didSet { defaults.set(chosen.map { Array($0).sorted() }, forKey: "mailAccounts") }
    }

    /// Seconds between two reads (spec GM-5).
    @Published var interval: Int {
        didSet { defaults.set(interval, forKey: "mailInterval"); restart() }
    }

    /// Mail is started hidden when it is not running (spec GM-9).
    @Published var keepsMailRunning: Bool {
        didSet { defaults.set(keepsMailRunning, forKey: "mailKeepRunning"); if keepsMailRunning { refresh() } }
    }

    private let settings: AppSettings
    private let defaults: UserDefaults
    private var timer: Timer?
    private var isReading = false
    private var settingsObserver: AnyCancellable?
    private var lastLogged: State?

    init(settings: AppSettings) {
        self.settings = settings
        defaults = settings.defaults
        chosen = defaults.stringArray(forKey: "mailAccounts").map(Set.init)
        let stored = defaults.object(forKey: "mailInterval") as? Int ?? 60
        interval = min(max(stored, Self.intervalRange.lowerBound), Self.intervalRange.upperBound)
        keepsMailRunning = defaults.object(forKey: "mailKeepRunning") as? Bool ?? true
    }

    /// Mail is the source of Gmail (spec GM-12).
    var isActive: Bool { settings.mailSource == .appleMail && settings.isEnabled(.notifications) }

    func start() {
        settingsObserver = settings.afterChange { [weak self] in
            guard let self, self.isActive != (self.timer != nil) else { return }
            self.restart()
        }
        restart()
    }

    func isShown(_ account: MailAccount) -> Bool {
        chosen.map { $0.contains(account.name) } ?? account.isGmail
    }

    func setShown(_ shown: Bool, for account: MailAccount) {
        var names = chosen ?? Set(accounts.filter(\.isGmail).map(\.name))
        if shown { names.insert(account.name) } else { names.remove(account.name) }
        chosen = names
    }

    /// The chosen accounts, as the notch shows them.
    var shownAccounts: [MailAccount] {
        state == .reading ? accounts.filter(isShown) : []
    }

    var gmailUnread: Int? {
        let gmail = shownAccounts.filter(\.isGmail)
        return gmail.isEmpty ? nil : gmail.reduce(0) { $0 + $1.unread }
    }

    var totalUnread: Int { shownAccounts.reduce(0) { $0 + $1.unread } }

    private func restart() {
        timer?.invalidate()
        timer = nil
        guard isActive else {
            state = .off
            accounts = []
            return
        }
        timer = RepeatingTimer.start(every: TimeInterval(interval)) { [weak self] in self?.refresh() }
        refresh()
    }

    /// Reads Mail now: on a timer, and at every Gmail or Mail notification (spec GM-5).
    func refresh() {
        guard isActive, !isReading else { return }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: Self.mailBundleID).isEmpty == false else {
            set(.notRunning)
            if keepsMailRunning { launchMailHidden() }
            return
        }
        isReading = true
        Task.detached(priority: .utility) {
            let result = ProcessRunner.run("/usr/bin/osascript", ["-l", "JavaScript", "-e", MailParser.script], timeout: 40)
            let parsed = result.flatMap { $0.succeeded ? MailParser.accounts(from: $0.output) : nil }
            let errors = result.map { String(bytes: $0.errors, encoding: .utf8) ?? "" } ?? ""
            await MainActor.run { [weak self] in self?.finish(parsed, errors: errors, timedOut: result?.timedOut == true) }
        }
    }

    private func finish(_ parsed: [MailAccount]?, errors: String, timedOut: Bool) {
        isReading = false
        guard isActive else { return }
        guard let parsed else {
            let lowered = errors.lowercased()
            let denied = lowered.contains("-1743") || lowered.contains("not authorized") || lowered.contains("not allowed")
            // Only the kind of failure goes to the log, never what Mail holds (spec GM-10).
            DiagnosticsLog.append("mail", "read failed: denied=\(denied) timedOut=\(timedOut)")
            set(denied ? .noAccess : .failed)
            return
        }
        if accounts != parsed { accounts = parsed }
        lastRead = Date()
        set(parsed.isEmpty ? .noAccounts : .reading)
    }

    private func set(_ next: State) {
        if state != next { state = next }
        guard next != lastLogged else { return }
        lastLogged = next
        let counts = accounts.filter(isShown).map { "\($0.unread)" }.joined(separator: ",")
        DiagnosticsLog.append("mail", "state \(next) · unread per shown account: [\(counts)]")
    }

    private func launchMailHidden() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.mailBundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(8))
                self?.refresh()
            }
        }
    }

    // MARK: - Opening (spec GM-8)

    /// A Gmail message opens in the Gmail web app (or the browser), any other in Mail.
    func open(_ message: MailMessage) {
        let isGmail = accounts.first { $0.name == message.account }?.isGmail ?? false
        let encoded = message.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let link = isGmail
            ? "https://mail.google.com/mail/u/0/#search/rfc822msgid%3A" + encoded
            : "message://%3C" + encoded + "%3E"
        guard let url = URL(string: link) else { return }
        if isGmail, let webApp = Self.gmailWebApp() {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: webApp, configuration: configuration, completionHandler: nil)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    /// The Gmail web app added to the Dock from Safari or Chrome: running, or in Applications.
    private static func gmailWebApp() -> URL? {
        if let running = NSWorkspace.shared.runningApplications.first(where: { app in
            (app.localizedName ?? "").localizedCaseInsensitiveContains("gmail") && app.bundleIdentifier != mailBundleID
        }), let url = running.bundleURL {
            return url
        }
        let folders = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"), URL(fileURLWithPath: "/Applications")
        ]
        return folders.map { $0.appendingPathComponent("Gmail.app") }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// System Settings › Notifications › Mail, to silence Mail itself (spec GM-9).
    func openMailNotificationSettings() {
        let link = "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=" + Self.mailBundleID
        if let url = URL(string: link) { NSWorkspace.shared.open(url) }
    }
}
