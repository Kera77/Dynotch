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
    @Published private(set) var recent: [AppNotification] = []
    /// Notification currently peeking out of the closed notch.
    @Published private(set) var peek: AppNotification?
    /// Installed apps found in the database, for the settings list.
    @Published private(set) var apps: [NotificationApp] = []

    let catalog = NotificationAppCatalog()

    private let settings: AppSettings
    private var database: NotificationDatabase?
    private var lastSeenID: Int64 = 0
    private var pollTimer: Timer?
    private var lastOpenAttempt = Date.distantPast
    private var peekTask: Task<Void, Never>?
    private var settingsObserver: AnyCancellable?

    private static let pollInterval: TimeInterval = 1
    private static let openRetryInterval: TimeInterval = 5
    private static let historyLimit = 50

    init(settings: AppSettings) {
        self.settings = settings
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

    func isEnabled(_ app: NotificationApp) -> Bool {
        settings.isNotificationAppEnabled(app.identifier, default: app.isDefaultEnabled)
    }

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
        apps = identifiers
            .map(catalog.app(for:))
            .filter { $0.url != nil && !WebNotificationSource.isShared($0.identifier) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    func openFullDiskAccessSettings() {
        Self.openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    func openNotificationSettings() {
        Self.openSettings("x-apple.systempreferences:com.apple.Notifications-Settings.extension")
    }

    // MARK: - Polling

    private func applyEnabled() {
        let enabled = settings.isEnabled(.notifications)
        if enabled, pollTimer == nil {
            let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.poll() }
            }
            RunLoop.main.add(timer, forMode: .common)
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
        do {
            let records = try database.records(after: lastSeenID)
            if !records.isEmpty { handle(records) }
        } catch {
            DiagnosticsLog.write("notifications", "read failed: \(error)")
            self.database = nil
            status = .unsupported("\(error)")
        }
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

    /// Without Full Disk Access SQLite reports "authorization denied" (or can't see the file).
    static func failureStatus(for failures: [String]) -> Status {
        let text = failures.joined(separator: "; ").lowercased()
        let denied = text.contains("authorization denied") || text.contains("not permitted")
        let foundElsewhere = failures.contains { !$0.lowercased().contains("unable to open database file") }
        return denied || !foundElsewhere ? .noAccess : .unsupported(failures.joined(separator: "; "))
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
            let notification = resolve(parsed)
            let enabled = isEnabled(catalog.app(for: notification.appIdentifier))
            // Identifiers and site only, never the notification's text.
            DiagnosticsLog.append(
                "notification-records",
                "#\(record.id) app=\(record.appIdentifier) site=\(parsed.site ?? "-") "
                    + "as=\(notification.appIdentifier) shown=\(enabled)"
            )
            if enabled {
                incoming.append(notification)
            }
        }
        guard let newest = incoming.last else { return }
        recent = Array((incoming.reversed() + recent).prefix(Self.historyLimit))
        showPeek(newest)
    }

    private func showPeek(_ notification: AppNotification) {
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

    private static func openSettings(_ link: String) {
        if let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
    }
}
