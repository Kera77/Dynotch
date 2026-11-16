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

    /// A badge's app and a notification's app are the same: the same identifier, or the same
    /// name (web apps post under the browser and are attributed by name).
    static func matches(bundleID: String, name: String, identifier: String, notificationAppName: String) -> Bool {
        identifier.caseInsensitiveCompare(bundleID) == .orderedSame
            || notificationAppName.caseInsensitiveCompare(name) == .orderedSame
    }
}

extension NotificationService {
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
