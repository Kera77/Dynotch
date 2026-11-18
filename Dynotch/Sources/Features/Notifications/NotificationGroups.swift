import AppKit

/// The notifications of one sender (or chat) in one app (spec E-5b).
struct NotificationGroup: Identifiable, Equatable, Sendable {
    let id: String
    /// Oldest first.
    let notifications: [AppNotification]
    let latest: AppNotification

    static func key(for notification: AppNotification) -> String {
        notification.appIdentifier.lowercased() + "|" + notification.title.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Groups by app and sender; the group with the newest notification comes first.
    static func groups(of notifications: [AppNotification]) -> [NotificationGroup] {
        var order: [String] = []
        var members: [String: [AppNotification]] = [:]
        for notification in notifications.sorted(by: { $0.date < $1.date }) {
            let key = key(for: notification)
            if members[key] == nil { order.append(key) }
            members[key, default: []].append(notification)
        }
        let groups = order.compactMap { key -> NotificationGroup? in
            guard let list = members[key], let latest = list.last else { return nil }
            return NotificationGroup(id: key, notifications: list, latest: latest)
        }
        return groups.sorted { $0.latest.date > $1.latest.date }
    }
}

/// One app's unopened notifications, shown after a click on its badge (spec B-6).
struct NotificationFocus: Equatable, Sendable {
    let appName: String
    let bundleID: String
    var notifications: [AppNotification]
    /// Changes with every badge click, so the list is built anew.
    var token = UUID()

    /// A badge's app and a notification's app are the same: the same identifier, or the same
    /// name (web apps post under the browser and are attributed by name).
    static func matches(bundleID: String, name: String, identifier: String, notificationAppName: String) -> Bool {
        identifier.caseInsensitiveCompare(bundleID) == .orderedSame
            || notificationAppName.caseInsensitiveCompare(name) == .orderedSame
    }
}

/// One line of a badge's hover list (spec B-10).
struct BadgeNotificationRow: Identifiable, Equatable, Sendable {
    let id: Int64
    let sender: String
    let detail: String
    let date: Date

    /// The newest `limit` messages under their sender's name, senders in order of their newest
    /// message (spec B-10b).
    nonisolated static func bySender(_ rows: [BadgeNotificationRow], limit: Int) -> [(sender: String, rows: [BadgeNotificationRow])] {
        var groups: [(sender: String, rows: [BadgeNotificationRow])] = []
        for row in rows.prefix(limit) {
            if let index = groups.firstIndex(where: { $0.sender == row.sender }) {
                groups[index].rows.append(row)
            } else {
                groups.append((row.sender, [row]))
            }
        }
        return groups
    }
}

extension BeeperService {
    /// Beeper's unread chats as badge list rows: Beeper takes its notifications out of
    /// Notification Center within seconds, but its chats still say what is unread (spec B-10c).
    func badgeRows() -> [BadgeNotificationRow] {
        unreadChats.enumerated().map { index, chat in
            BadgeNotificationRow(
                id: -1 - Int64(index), sender: chat.name, detail: chat.preview?.text ?? "\(chat.unread) unread",
                date: chat.preview?.timestamp.flatMap { try? Date($0, strategy: .iso8601) } ?? Date()
            )
        }
    }
}

extension NotificationService {
    /// What a badge's hover list shows: its notifications, or for Beeper its unread chats when
    /// none are left in Notification Center (spec B-10, B-10c).
    func badgeListRows(for app: BadgeApp, beeper: BeeperService) -> [BadgeNotificationRow] {
        let rows = badgeRows(for: app)
        guard rows.isEmpty, app.bundleID.lowercased().contains("beeper"), beeper.state == .ready else { return rows }
        return beeper.badgeRows()
    }

    /// The app's notifications still in Notification Center, newest first, for its badge's
    /// hover list (spec B-10).
    func badgeRows(for app: BadgeApp) -> [BadgeNotificationRow] {
        recent.filter {
            NotificationFocus.matches(
                bundleID: app.bundleID, name: app.name,
                identifier: $0.appIdentifier, notificationAppName: catalog.app(for: $0.appIdentifier).name
            )
        }
        .map { notification in
            let content = content(for: notification)
            return BadgeNotificationRow(id: notification.id, sender: content.sender, detail: content.detail, date: notification.date)
        }
    }

    /// Limits the Notifications feature to the unopened notifications of one app: its newest
    /// ones, as many as its badge counts.
    func setFocus(bundleID: String, name: String, count: Int?) {
        let matching = recent.filter {
            NotificationFocus.matches(
                bundleID: bundleID, name: name,
                identifier: $0.appIdentifier, notificationAppName: catalog.app(for: $0.appIdentifier).name
            )
        }
        let newest = count.map { Array(matching.prefix(max($0, 0))) } ?? matching
        focus = NotificationFocus(appName: name, bundleID: bundleID, notifications: newest)
    }

    func openApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    func clearFocus() {
        if focus != nil { focus = nil }
    }
}

/// Finds notifications that were dealt with in their app (spec E-13).
enum NotificationCleanup {
    /// Younger notifications are left alone: their record may not be visible yet.
    static let minimumAge: TimeInterval = 5

    /// The listed notifications whose record is gone from Notification Center. Dynotch's own
    /// notices (negative ids) have no record and stay.
    static func handled(
        recent: [AppNotification], now: Date, stillPresent: (Int64) throws -> Set<Int64>
    ) rethrows -> Set<Int64> {
        let candidates = recent.filter { $0.id > 0 && now.timeIntervalSince($0.date) >= minimumAge }
        guard let lowest = candidates.map(\.id).min() else { return [] }
        let present = try stillPresent(lowest)
        return Set(candidates.map(\.id)).subtracting(present)
    }
}
