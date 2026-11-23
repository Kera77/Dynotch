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
        case noDiskAccess
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

    /// Gmail's label for its Primary tab: only the Inbox mail with it counts (spec GM-16).
    @Published var primaryLabel: String {
        didSet { defaults.set(primaryLabel, forKey: "mailPrimaryLabel"); refresh() }
    }

    private let settings: AppSettings
    private let defaults: UserDefaults
    private var timer: Timer?
    private var isReading = false
    private var settingsObserver: AnyCancellable?
    private var lastLogged: State?
    private var quitObserver: NSObjectProtocol?
    /// Reads that ran out of time in a row; each one waits longer before the next (spec GM-14).
    private var timeouts = 0
    private var pausedUntil: Date?
    /// Mail was quit (or force quit): Dynotch does not start it again until it runs and answers
    /// (spec GM-15).
    private var mailWasQuit = false
    /// Mail's accounts, asked again after `accountsAge` (spec GM-13).
    private var infos: [MailAccountInfo]?
    private var infosRead: Date?
    static let accountsAge: TimeInterval = 600

    /// The waits after the 1st, 2nd, 3rd and later timeouts in a row (spec GM-14).
    static let backoff: [TimeInterval] = [60, 120, 300, 900]

    init(settings: AppSettings) {
        self.settings = settings
        defaults = settings.defaults
        chosen = defaults.stringArray(forKey: "mailAccounts").map(Set.init)
        let stored = defaults.object(forKey: "mailInterval") as? Int ?? 60
        interval = min(max(stored, Self.intervalRange.lowerBound), Self.intervalRange.upperBound)
        keepsMailRunning = defaults.object(forKey: "mailKeepRunning") as? Bool ?? true
        primaryLabel = defaults.string(forKey: "mailPrimaryLabel") ?? "Primary"
    }

    /// Mail is the source of Gmail (spec GM-12).
    var isActive: Bool { settings.mailSource == .appleMail && settings.isEnabled(.notifications) }

    func start() {
        quitObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == MailService.mailBundleID else { return }
            MainActor.assumeIsolated { self?.mailQuit() }
        }
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
        // After a timeout Mail is left alone for a while (spec GM-14).
        if let pausedUntil, pausedUntil > Date() { return }
        let mailRuns = !NSRunningApplication.runningApplications(withBundleIdentifier: Self.mailBundleID).isEmpty
        if !mailRuns, keepsMailRunning, !mailWasQuit { launchMailHidden() }
        // Mail is asked only for its accounts, and only now and then (spec GM-13).
        let asksAccounts = mailRuns && (infos == nil || infosRead.map { Date().timeIntervalSince($0) > Self.accountsAge } ?? true)
        guard asksAccounts || infos != nil else {
            set(.notRunning)
            return
        }
        guard let path = MailDatabase.defaultPath else {
            DiagnosticsLog.append("mail", "Mail's folder can't be listed")
            set(.noDiskAccess)
            return
        }
        isReading = true
        let known = infos
        let label = primaryLabel
        Task.detached(priority: .utility) {
            let outcome = Self.read(known: known, asksAccounts: asksAccounts, path: path, label: label)
            await MainActor.run { [weak self] in self?.finish(outcome) }
        }
    }

    /// What one read found: Mail's accounts (when asked) and the index's unread headers.
    private struct Outcome: Sendable {
        var infos: [MailAccountInfo]?
        var accounts: [MailAccount]?
        var scriptErrors = ""
        var timedOut = false
        var databaseError: String?
    }

    /// Blocks: runs off the main thread.
    nonisolated private static func read(known: [MailAccountInfo]?, asksAccounts: Bool, path: String, label: String) -> Outcome {
        var outcome = Outcome()
        var current = known
        if asksAccounts {
            let result = ProcessRunner.run("/usr/bin/osascript", ["-e", MailParser.accountScript], timeout: 15)
            if let result, result.succeeded, let parsed = MailParser.accountInfos(from: result.output) {
                outcome.infos = parsed
                current = parsed
            } else {
                outcome.scriptErrors = result.map { String(bytes: $0.errors, encoding: .utf8) ?? "" } ?? ""
                outcome.timedOut = result?.timedOut == true
            }
        }
        guard let current else { return outcome }
        do {
            outcome.accounts = try MailDatabase.read(accounts: current, path: path, label: label)
        } catch {
            outcome.databaseError = String(describing: error)
        }
        return outcome
    }

    private func finish(_ outcome: Outcome) {
        isReading = false
        guard isActive else { return }
        if let fresh = outcome.infos {
            infos = fresh
            infosRead = Date()
            timeouts = 0
            pausedUntil = nil
            mailWasQuit = false
        } else if outcome.timedOut || !outcome.scriptErrors.isEmpty {
            let lowered = outcome.scriptErrors.lowercased()
            let denied = lowered.contains("-1743") || lowered.contains("not authorized") || lowered.contains("not allowed")
            // Only the kind of failure goes to the log, never what Mail holds (spec GM-10).
            DiagnosticsLog.append("mail", "accounts not read: denied=\(denied) timedOut=\(outcome.timedOut)")
            if outcome.timedOut { pauseAfterTimeout() }
            if infos == nil {
                set(denied ? .noAccess : .failed)
                return
            }
        }
        if let error = outcome.databaseError {
            DiagnosticsLog.append("mail", "index not read: \(error)")
            let lowered = error.lowercased()
            let blocked = lowered.contains("authorization denied") || lowered.contains("unable to open")
            set(blocked ? .noDiskAccess : .failed)
            return
        }
        guard let read = outcome.accounts else { return }
        if accounts != read { accounts = read }
        lastRead = Date()
        set(read.isEmpty ? .noAccounts : .reading)
    }

    private func set(_ next: State) {
        if state != next { state = next }
        guard next != lastLogged else { return }
        lastLogged = next
        let counts = accounts.filter(isShown).map { "\($0.unread)" }.joined(separator: ",")
        DiagnosticsLog.append("mail", "state \(next) · unread per shown account: [\(counts)]")
    }

    /// Mail is busy: the next read waits 1, 2, 5, then 15 minutes (spec GM-14).
    private func pauseAfterTimeout() {
        let wait = Self.backoff[min(timeouts, Self.backoff.count - 1)]
        timeouts += 1
        pausedUntil = Date().addingTimeInterval(wait)
        DiagnosticsLog.append("mail", "timeout #\(timeouts) in a row: next read in \(Int(wait)) s")
    }

    /// The owner quit Mail (or it was force quit while busy): it is not started again (spec GM-15).
    private func mailQuit() {
        guard !mailWasQuit else { return }
        mailWasQuit = true
        DiagnosticsLog.append("mail", "Mail quit: not starting it again until it runs")
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

    /// A Gmail message opens in the Gmail web app (or the browser in use, spec E-2f), any other in Mail.
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
        } else if isGmail {
            ActiveBrowser.shared.open(url)
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
