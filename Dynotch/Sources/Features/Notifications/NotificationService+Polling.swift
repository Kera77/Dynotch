import Foundation

// Results of a look at the Notification Center database.
extension NotificationService {
    func finishPoll(_ result: NotificationPoll, from polled: NotificationDatabase, lowest: Int64?) {
        isPolling = false
        guard polled === database else { return }
        if let failure = result.failure {
            DiagnosticsLog.write("notifications", "read failed: \(failure)")
            database = nil
            status = .unsupported(failure)
            return
        }
        if !result.records.isEmpty { handle(result.records) }
        if result.latestDelivered > lastDelivered { lastDelivered = result.latestDelivered }
        if !result.updated.isEmpty {
            DiagnosticsLog.append("notification-records", "updated in place: \(result.updated.map(\.id))")
            handle(result.updated)
        }
        if let lowest, let present = result.present { dropHandled(present: present, from: lowest) }
        if pollAgain {
            pollAgain = false
            poll()
        }
    }

    /// A notification that left Notification Center was dealt with in its app (read or answered
    /// there): it leaves the list here too (spec E-13).
    func dropHandled(present: Set<Int64>, from lowest: Int64) {
        let gone = NotificationCleanup.handled(
            recent: recent.filter { $0.id >= lowest }, now: Date(), stillPresent: { _ in present }
        )
        .subtracting(bannerDismisser.closedIDs)
        guard !gone.isEmpty else { return }
        // Identifiers only: which notifications left with Notification Center (spec E-13).
        let apps = recent.filter { gone.contains($0.id) }.map { "#\($0.id) \($0.appIdentifier)" }
        DiagnosticsLog.append("notification-records", "left Notification Center: " + apps.joined(separator: ", "))
        // Websites close their own notifications: those stay, under an id of their own, as the
        // record id is soon given to a new notification (spec E-13c).
        for kept in recent where gone.contains(kept.id) && kept.isFromBrowser {
            internalID -= 1
            rekey(kept.id, to: internalID)
        }
        recent.removeAll { gone.contains($0.id) }
        unseen.removeAll { gone.contains($0.id) }
        focus?.notifications.removeAll { gone.contains($0.id) }
        if let peek, gone.contains(peek.id) { clearPeek() }
    }
}
