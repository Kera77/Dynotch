import AppKit
import Combine

/// Mirrors new macOS notifications of the selected apps into the notch (spec E-1…E-9).
@MainActor
final class NotificationService: ObservableObject {
    enum Status: Equatable {
        case disabled
        /// The database can't be read: Full Disk Access is missing.
        case noAccess
        /// The database was found but can't be used (e.g. changed format).
        case unsupported(String)
        case running
    }

    @Published var status: Status = .disabled
    /// Notifications received since launch, newest first.
    @Published var recent: [AppNotification] = []
    /// Notification currently peeking out of the closed notch.
    @Published private(set) var peek: AppNotification?
    /// Arrived since the user last looked (hover card or Notifications feature), oldest first
    /// (spec E-4).
    @Published var unseen: [AppNotification] = []
    /// The Notifications feature shows only these: one app's unopened notifications, after a
    /// click on its badge (spec B-6).
    @Published var focus: NotificationFocus?
    /// A chat picked in a badge's drop-down, to open ready to answer (spec B-10f).
    @Published var cardRequest: CardOpenRequest?
    /// Installed apps found in the database, for the settings list.
    @Published private(set) var apps: [NotificationApp] = []
    /// The screen is shared or recorded: nothing pops up (spec N-21).
    var isScreenShared = false

    let catalog = NotificationAppCatalog()
    /// Google Chat read from its web app (spec GW-1).
    let chatWeb: GoogleChatWebService
    /// Gmail and other accounts read from Apple Mail (spec GM-1).
    let mail: MailService
    /// The websites seen and every source's rules (spec E-15).
    let preferences: NotificationPreferences
    private var preferencesObserver: AnyCancellable?
    let bannerDismisser = NativeBannerDismisser()

    let settings: AppSettings
    var database: NotificationDatabase?
    private(set) var lastSeenID: Int64 = 0
    /// The latest delivery seen, to catch records updated in place (spec E-1d).
    var lastDelivered: Double = 0
    private var pollTimer: Poller?
    private var lastOpenAttempt = Date.distantPast
    private var pollCount = 0
    var isPolling = false
    var pollAgain = false
    private var peekTask: Task<Void, Never>?
    /// The notch panels whose pointer rests on the peek beside the notch (spec PV-39).
    var peekHolders: Set<ObjectIdentifier> = []
    /// A newer notification that waits until the pointer leaves the shown one (spec PV-39).
    var heldPeek: AppNotification?
    private var settingsObserver: AnyCancellable?

    /// The database is watched for writes; this is only the fallback (spec E-1b, RF-12).
    private static let pollInterval: TimeInterval = 30
    private let walWatcher = FolderWatcher()
    private var walWatchRenewed = Date.distantPast
    private static let openRetryInterval: TimeInterval = 5
    static let historyLimit = 50

    init(settings: AppSettings) {
        self.settings = settings
        preferences = NotificationPreferences(defaults: settings.defaults)
        chatWeb = GoogleChatWebService(defaults: settings.defaults)
        mail = MailService(settings: settings)
        catalog.update(sites: preferences.sites, names: preferences.names)
        preferencesObserver = preferences.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.catalog.update(sites: self.preferences.sites, names: self.preferences.names)
                    // The settings list the websites; a new one shows up there at once.
                    self.objectWillChange.send()
                }
            }
        }
    }

    func start() {
        settingsObserver = settings.afterChange { [weak self] in self?.applyEnabled() }
        applyEnabled()
        mail.start()
        // Web pages and replies go to the browser in use (spec E-2f).
        ActiveBrowser.shared.start()
    }

    func content(for notification: AppNotification) -> NotificationContent {
        let app = catalog.app(for: notification.appIdentifier)
        let content = NotificationPresenter.content(for: notification, appName: app.name, kind: app.kind)
        // The messages read from the web app when the card was opened (spec GW-5c).
        guard let lines = chatWebTexts[notification.id], !lines.isEmpty else { return content }
        return NotificationContent(sender: content.sender, detail: lines.map(\.text).joined(separator: "\n"), lines: lines)
    }

    /// Dynotch's own notifications (e.g. Claude usage, spec CL-5) shown like any other one.
    func present(title: String, body: String, appIdentifier: String, kind: DynotchAlert? = nil) {
        // A kind turned off neither pops up nor is listed (spec E-25).
        if let kind, !preferences.isOn(kind) { return }
        internalID -= 1
        let notification = AppNotification(
            id: internalID, appIdentifier: appIdentifier, title: title, subtitle: "", body: body, date: Date()
        )
        recent = Array(([notification] + recent).prefix(Self.historyLimit))
        unseen = Array((unseen + [notification]).suffix(Self.unseenLimit))
        showPeek(notification)
    }

    static let unseenLimit = 12

    /// Negative ids never clash with the database's record ids.
    var internalID: Int64 = 0
    /// Messages read from the web app for a card made without a notification, by card id (spec GW-5c).
    @Published var chatWebTexts: [Int64: [ChatWebMessage]] = [:]
    /// Cards opened whose conversation is being opened in the web app, by conversation id.
    var chatWebPending: [String: Int64] = [:]
    /// Cards whose conversation Dynotch read in the web app to show them: card id → conversation
    /// id. Opened there, it stays read (spec GW-17c).
    var chatWebOpened: [Int64: String] = [:]
    /// Cards kept although the web app shows their conversation read: open, or just marked
    /// unread again (spec GW-17); card id → until when.
    var chatWebHeld: [Int64: Date] = [:]
    /// Google Chat conversations that got a card while unread, without a notification (spec GW-5b).
    var chatUnreadCarded: Set<String> = []
    /// The last "unread without a card" log line, written once per change (spec GW-25).
    var chatSkippedLogged = ""
    /// The web app was read once since launch: unread conversations found later pop up.
    var chatWebPrimed = false

    func clearPeek() {
        peekTask?.cancel()
        peekTask = nil
        heldPeek = nil
        if peek != nil { peek = nil }
    }

    func clearHistory() {
        recent = []
    }

    func refreshApps() {
        guard let identifiers = try? database?.appIdentifiers() else { return }
        let found = identifiers
            .map(catalog.app(for:))
            // The shared Web App host is not an app of its own; its notifications are attributed.
            // System notices are listed once, as "System Settings".
            .filter { $0.url != nil && !$0.isSystem && $0.identifier.lowercased() != "com.apple.safari.webapp" }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        apps = [catalog.app(for: NotificationApp.systemGroupID)] + found
        if let sites = try? database?.browserSites() { registerSites(sites) }
    }

    // MARK: - Polling

    private func applyEnabled() {
        let enabled = settings.isEnabled(.notifications)
        // Ask once for the permission that hiding the native banners needs.
        if enabled, settings.hideNativeBanners, !NativeBannerDismisser.isTrusted,
           !UserDefaults.standard.bool(forKey: "askedAccessibility") {
            UserDefaults.standard.set(true, forKey: "askedAccessibility")
            NativeBannerDismisser.requestTrust()
        }
        if enabled, pollTimer == nil {
            // Not slowed on battery: it also releases the snoozed notifications on time.
            pollTimer = Poller.start(every: Self.openRetryInterval, scalesWithPower: false) { [weak self] in self?.poll() }
            poll()
            startChatWeb()
        } else if !enabled, pollTimer != nil {
            pollTimer?.invalidate()
            pollTimer = nil
            database = nil
            status = .disabled
            clearPeek()
            chatWeb.stop()
        }
    }

    func poll() {
        guard let database else {
            openDatabaseIfDue()
            return
        }
        releaseSnoozed()
        // Now and then the watch is renewed, in case the log file was replaced; at once when it is back.
        let hasLog = FileManager.default.fileExists(atPath: database.path + "-wal")
        if hasLog, pollTimer?.interval != Self.pollInterval || Date().timeIntervalSince(walWatchRenewed) > 30 {
            walWatchRenewed = Date()
            walWatcher.watch(URL(fileURLWithPath: database.path + "-wal"), renew: true) { [weak self] in self?.poll() }
        }
        // Without the log file nothing tells of new notifications: the fallback looks more often (spec RF-12).
        pollTimer?.interval = hasLog ? Self.pollInterval : Self.openRetryInterval
        guard !isPolling else {
            pollAgain = true
            return
        }
        isPolling = true
        pollCount += 1
        // Every third look also checks which notifications left Notification Center (spec E-13).
        let lowest = pollCount.isMultiple(of: 3)
            ? recent.filter { $0.id > 0 && Date().timeIntervalSince($0.date) >= NotificationCleanup.minimumAge }.map(\.id).min()
            : nil
        let after = lastSeenID
        let delivered = lastDelivered
        Task { [weak self] in
            let result = await Task.detached { database.poll(after: after, deliveredAfter: delivered, presentFrom: lowest) }.value
            self?.finishPoll(result, from: database, lowest: lowest)
        }
    }

    func rekey(_ id: Int64, to newID: Int64) {
        func swap(_ item: AppNotification) -> AppNotification { item.id == id ? item.with(id: newID) : item }
        recent = recent.map(swap)
        unseen = unseen.map(swap)
        if let notifications = focus?.notifications { focus?.notifications = notifications.map(swap) }
        if let current = peek, current.id == id { peek = current.with(id: newID) }
    }

    private func openDatabaseIfDue() {
        guard Date().timeIntervalSince(lastOpenAttempt) >= Self.openRetryInterval else { return }
        lastOpenAttempt = Date()

        var failures: [String] = []
        for path in NotificationDatabase.candidatePaths {
            do {
                let opened = try NotificationDatabase(path: path)
                lastSeenID = try opened.maxRecordID()
                lastDelivered = opened.lastDelivered()
                database = opened
                status = .running
                // New notifications are written to the write-ahead log: read them at once.
                walWatcher.watch(URL(fileURLWithPath: path + "-wal")) { [weak self] in self?.poll() }
                DiagnosticsLog.write("notifications", opened.diagnostics())
                refreshApps()
                return
            } catch {
                failures.append("\(path): \(error)")
            }
        }
        let newStatus = Self.failureStatus(for: failures)
        if newStatus != status {
            status = newStatus
            DiagnosticsLog.write("notifications", "open failed -> \(newStatus)\n" + failures.joined(separator: "\n"))
        }
    }

    func handle(_ records: [NotificationRecord]) {
        var incoming: [AppNotification] = []
        let defaultBrowser = records.isEmpty ? nil : ActiveBrowser.defaultBundleID()
        for record in records {
            lastSeenID = max(lastSeenID, record.id)
            guard let parsed = NotificationParser.parse(
                recordID: record.id, appIdentifier: record.appIdentifier, data: record.data
            ) else {
                DiagnosticsLog.append("notification-records", "#\(record.id) app=\(record.appIdentifier) unparsed")
                continue
            }
            let notification = attribute(parsed)
            // Only the default browser's notifications are watched (spec E-2g).
            let otherBrowser = WebNotificationSource.isFromOtherBrowser(record.appIdentifier, defaultBrowser: defaultBrowser)
            let enabled = !otherBrowser && isEnabled(catalog.app(for: notification.appIdentifier))
            // Identifiers and site only, never the notification's text.
            DiagnosticsLog.append(
                "notification-records",
                "#\(record.id) app=\(record.appIdentifier) site=\(parsed.site ?? "-") "
                    + "link=\(parsed.link.map(WebNotificationSource.maskedShape) ?? "-") "
                    + "as=\(notification.appIdentifier) shown=\(enabled)\(otherBrowser ? " (not the default browser)" : "") "
                    + "fields=\(NotificationParser.keySummary(of: record.data))"
            )
            if enabled {
                incoming.append(notification)
                if hidesBanner(for: notification.appIdentifier) { bannerDismisser.dismiss(notification) }
            }
        }
        guard let newest = incoming.last else { return }
        noticed(incoming, newest: newest)
        // A record updated in place replaces its earlier version (spec E-1d).
        let ids = Set(incoming.map(\.id))
        // A kept website notification posted again replaces the kept copy (spec E-13c).
        let replaced = { (old: AppNotification) in
            ids.contains(old.id) || (old.id < 0 && incoming.contains { $0.repeats(old) })
                || self.isReplacedChatCard(old, by: incoming)
        }
        recent.removeAll(where: replaced)
        unseen.removeAll(where: replaced)
        recent = Array((incoming.reversed() + recent).prefix(Self.historyLimit))
        unseen = Array((unseen + incoming).suffix(Self.unseenLimit))
        showPeek(newest)
    }

    func showPeekAgain(_ notification: AppNotification) {
        showPeek(notification)
    }

    func showPeek(_ notification: AppNotification) {
        // During a Focus, or while the screen is shared, it is listed without popping up (spec E-20d, N-21).
        guard popsUp(notification), !isScreenShared else { return }
        // The pointer rests on the one beside the notch: the newer one waits (spec PV-39).
        if !peekHolders.isEmpty, peek != nil {
            heldPeek = notification
            return
        }
        peekTask?.cancel()
        heldPeek = nil
        peek = notification
        let duration = settings.notificationDuration
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            // It stays while the pointer is on it (spec PV-39).
            while !Task.isCancelled, self?.peekHolders.isEmpty == false {
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard !Task.isCancelled, let self else { return }
            self.peekTask = nil
            // A newer peek or a re-keyed one (spec E-13c) cancels or keeps this task.
            self.peek = nil
        }
    }
}

extension NotificationService {
    func openFullDiskAccessSettings() {
        Self.openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    func openNotificationSettings() {
        Self.openSettings("x-apple.systempreferences:com.apple.Notifications-Settings.extension")
    }

    private static func openSettings(_ link: String) {
        if let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
    }
}

extension NotificationService {
    /// Without Full Disk Access SQLite reports "authorization denied" (or can't see the file).
    static func failureStatus(for failures: [String]) -> Status {
        let text = failures.joined(separator: "; ").lowercased()
        let denied = text.contains("authorization denied") || text.contains("not permitted")
        let foundElsewhere = failures.contains { !$0.lowercased().contains("unable to open database file") }
        return denied || !foundElsewhere ? .noAccess : .unsupported(failures.joined(separator: "; "))
    }
}

extension NotificationService {
    func removeFromLists(_ ids: Set<Int64>) {
        recent.removeAll { ids.contains($0.id) }
        unseen.removeAll { ids.contains($0.id) }
        if let peek, ids.contains(peek.id) { clearPeek() }
    }

    /// A snoozed notification comes back: listed, new, popping up.
    func bringBack(_ notification: AppNotification) {
        recent = Array(([notification] + recent).prefix(50))
        unseen.append(notification)
        showPeekAgain(notification)
    }
}

extension NotificationService {
    /// Called once the new notifications were seen (all, or the given ones).
    func markSeen(_ seen: [AppNotification]? = nil) {
        guard let seen else {
            if !unseen.isEmpty { unseen = [] }
            return
        }
        let ids = Set(seen.map(\.id))
        unseen.removeAll { ids.contains($0.id) }
    }

    /// Removes one notification from the list (spec E-12).
    func remove(_ notification: AppNotification) {
        recent.removeAll { $0.id == notification.id }
        unseen.removeAll { $0.id == notification.id }
        focus?.notifications.removeAll { $0.id == notification.id }
        if peek?.id == notification.id { clearPeek() }
    }

    /// Removes every notification (spec E-12).
    func clearAll() {
        recent = []
        unseen = []
        focus?.notifications = []
        clearPeek()
    }
}
