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

    @Published private(set) var status: Status = .disabled
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
    /// Installed apps found in the database, for the settings list.
    @Published private(set) var apps: [NotificationApp] = []
    /// The screen is shared or recorded: nothing pops up (spec N-21).
    var isScreenShared = false

    let catalog = NotificationAppCatalog()
    /// The websites seen and every source's rules (spec E-15).
    let preferences: NotificationPreferences
    private var preferencesObserver: AnyCancellable?
    private let bannerDismisser = NativeBannerDismisser()

    let settings: AppSettings
    private var database: NotificationDatabase?
    private var lastSeenID: Int64 = 0
    private var pollTimer: Timer?
    private var lastOpenAttempt = Date.distantPast
    private var pollCount = 0
    private var peekTask: Task<Void, Never>?
    private var settingsObserver: AnyCancellable?

    /// The database is watched for writes; this is only the fallback (spec E-1b).
    private static let pollInterval: TimeInterval = 5
    private let walWatcher = FolderWatcher()
    private var walWatchRenewed = Date.distantPast
    private static let openRetryInterval: TimeInterval = 5
    private static let historyLimit = 50

    init(settings: AppSettings) {
        self.settings = settings
        preferences = NotificationPreferences(defaults: settings.defaults)
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
        settingsObserver = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.applyEnabled() }
            }
        }
        applyEnabled()
    }

    func content(for notification: AppNotification) -> NotificationContent {
        let app = catalog.app(for: notification.appIdentifier)
        return NotificationPresenter.content(for: notification, appName: app.name, kind: app.kind)
    }

    /// Dynotch's own notifications (e.g. Claude usage, spec CL-5) shown like any other one.
    func present(title: String, body: String, appIdentifier: String) {
        internalID -= 1
        let notification = AppNotification(
            id: internalID, appIdentifier: appIdentifier, title: title, subtitle: "", body: body, date: Date()
        )
        recent = Array(([notification] + recent).prefix(Self.historyLimit))
        unseen = Array((unseen + [notification]).suffix(Self.unseenLimit))
        showPeek(notification)
    }

    private static let unseenLimit = 12

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

    /// The new notifications from the same app and sender (or chat) as this one, oldest first
    /// (spec E-4).
    func related(to notification: AppNotification) -> [AppNotification] {
        let group = unseen.filter { Self.sameConversation($0, notification) }
        return group.isEmpty ? [notification] : group
    }

    nonisolated static func sameConversation(_ lhs: AppNotification, _ rhs: AppNotification) -> Bool {
        lhs.appIdentifier == rhs.appIdentifier
            && lhs.title.trimmingCharacters(in: .whitespaces).lowercased() == rhs.title.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Negative ids never clash with the database's record ids.
    private var internalID: Int64 = 0

    func clearPeek() {
        peekTask?.cancel()
        peekTask = nil
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

    /// Notifications posted under a shared Safari identifier are attributed to the web app of
    /// their site (spec E-2b).
    func resolve(_ notification: AppNotification) -> AppNotification {
        let pairs = apps.map { (identifier: $0.identifier, name: $0.name) }
        let identifier = WebNotificationSource.resolvedIdentifier(
            notification.appIdentifier, site: notification.site, apps: pairs
        )
        return identifier == notification.appIdentifier ? notification : notification.with(appIdentifier: identifier)
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
            let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
            RunLoop.main.add(timer, forMode: .common)
            timer.tolerance = timer.timeInterval * 0.2
            pollTimer = timer
            poll()
        } else if !enabled, pollTimer != nil {
            pollTimer?.invalidate()
            pollTimer = nil
            database = nil
            status = .disabled
            clearPeek()
        }
    }

    private func poll() {
        guard let database else {
            openDatabaseIfDue()
            return
        }
        releaseSnoozed()
        // Now and then the watch is renewed, in case the log file was replaced.
        if Date().timeIntervalSince(walWatchRenewed) > 30 {
            walWatchRenewed = Date()
            walWatcher.watch(URL(fileURLWithPath: database.path + "-wal"), renew: true) { [weak self] in self?.poll() }
        }
        do {
            let records = try database.records(after: lastSeenID)
            if !records.isEmpty { handle(records) }
            try dropHandled(in: database)
        } catch {
            DiagnosticsLog.write("notifications", "read failed: \(error)")
            self.database = nil
            status = .unsupported("\(error)")
        }
    }

    /// A notification that left Notification Center was dealt with in its app (read or answered
    /// there): it leaves the list here too (spec E-13). Checked every few seconds.
    private func dropHandled(in database: NotificationDatabase) throws {
        pollCount += 1
        guard pollCount.isMultiple(of: 3) else { return }
        let gone = try NotificationCleanup.handled(
            recent: recent, now: Date(), stillPresent: { try database.recordIDs(from: $0) }
        )
        .subtracting(bannerDismisser.closedIDs)
        guard !gone.isEmpty else { return }
        // Identifiers only: which notifications left with Notification Center (spec E-13).
        let apps = recent.filter { gone.contains($0.id) }.map { "#\($0.id) \($0.appIdentifier)" }
        DiagnosticsLog.append("notification-records", "left Notification Center: " + apps.joined(separator: ", "))
        recent.removeAll { gone.contains($0.id) }
        unseen.removeAll { gone.contains($0.id) }
        focus?.notifications.removeAll { gone.contains($0.id) }
        if let peek, gone.contains(peek.id) { clearPeek() }
    }

    private func openDatabaseIfDue() {
        guard Date().timeIntervalSince(lastOpenAttempt) >= Self.openRetryInterval else { return }
        lastOpenAttempt = Date()

        var failures: [String] = []
        for path in NotificationDatabase.candidatePaths {
            do {
                let opened = try NotificationDatabase(path: path)
                lastSeenID = try opened.maxRecordID()
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

    private func handle(_ records: [NotificationRecord]) {
        var incoming: [AppNotification] = []
        for record in records {
            lastSeenID = max(lastSeenID, record.id)
            guard let parsed = NotificationParser.parse(
                recordID: record.id, appIdentifier: record.appIdentifier, data: record.data
            ) else {
                DiagnosticsLog.append("notification-records", "#\(record.id) app=\(record.appIdentifier) unparsed")
                continue
            }
            let notification = attribute(parsed)
            let enabled = isEnabled(catalog.app(for: notification.appIdentifier))
            // Identifiers and site only, never the notification's text.
            DiagnosticsLog.append(
                "notification-records",
                "#\(record.id) app=\(record.appIdentifier) site=\(parsed.site ?? "-") "
                    + "link=\(parsed.link.map(WebNotificationSource.maskedShape) ?? "-") "
                    + "as=\(notification.appIdentifier) shown=\(enabled) "
                    + "fields=\(NotificationParser.keySummary(of: record.data))"
            )
            if enabled {
                incoming.append(notification)
                if hidesBanner(for: notification.appIdentifier) { bannerDismisser.dismiss(notification) }
            }
        }
        guard let newest = incoming.last else { return }
        recent = Array((incoming.reversed() + recent).prefix(Self.historyLimit))
        unseen = Array((unseen + incoming).suffix(Self.unseenLimit))
        showPeek(newest)
    }

    func showPeekAgain(_ notification: AppNotification) {
        showPeek(notification)
    }

    private func showPeek(_ notification: AppNotification) {
        // During a Focus, or while the screen is shared, it is listed without popping up (spec E-20, N-21).
        guard popsUp(notification), !isScreenShared else { return }
        peekTask?.cancel()
        peek = notification
        let duration = settings.notificationDuration
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self else { return }
            self.peekTask = nil
            if self.peek?.id == notification.id { self.peek = nil }
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
