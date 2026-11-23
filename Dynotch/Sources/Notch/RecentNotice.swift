import Foundation

/// The latest notification or notice and the module it belongs to: for a while every opening by
/// hover goes there (spec SO-9). The AI's notices do not count.
@MainActor
final class RecentNotice {
    static let shared = RecentNotice()

    struct Entry: Equatable, Sendable {
        let feature: FeatureID
        /// The notifications module's tab for the source (spec UM-8).
        var tab: NotificationsTab?
        /// A finished download, put on top of the tray (spec SO-6).
        var file: URL?
        let id: String
        let date: Date
    }

    private(set) var latest: Entry?

    func note(_ feature: FeatureID, tab: NotificationsTab? = nil, file: URL? = nil, id: String, now: Date = Date()) {
        latest = Entry(feature: feature, tab: tab, file: file, id: id, date: now)
    }

    /// The latest notice while its window lasts; a notification deleted in the notch ends it (spec SO-9).
    func live(now: Date, listed: [AppNotification]) -> Entry? {
        guard let entry = SmartOpening.liveNotice(latest, now: now, window: SmartOpening.noticeWindow) else { return nil }
        if entry.feature == .notifications, !listed.contains(where: { "n\($0.id)" == entry.id }) { return nil }
        return entry
    }
}

extension NotificationService {
    /// New notifications: the web app's texts, the mail, and the module hovering opens for a while (spec SO-9).
    func noticed(_ incoming: [AppNotification], newest: AppNotification) {
        chatWebNoticed(incoming)
        mailNoticed(incoming)
        let tab = SmartOpening.tab(
            isBeeper: ChatSources.isBeeper(newest), isGoogleChat: ChatSources.isGoogleChat(newest, catalog: catalog)
        )
        RecentNotice.shared.note(.notifications, tab: tab, id: "n\(newest.id)")
    }
}

extension SmartOpening {
    static let noticeMinutesKey = "smartNoticeMinutes"
    static let noticeMinutesRange: ClosedRange<Int> = 1...15

    /// Minutes the latest notification leads the hover (spec SO-10), 5 by default.
    static var noticeWindow: TimeInterval {
        let stored = UserDefaults.standard.object(forKey: noticeMinutesKey) as? Int ?? 5
        return TimeInterval(min(max(stored, noticeMinutesRange.lowerBound), noticeMinutesRange.upperBound) * 60)
    }

    /// The latest notice while its window lasts.
    nonisolated static func liveNotice(_ entry: RecentNotice.Entry?, now: Date, window: TimeInterval) -> RecentNotice.Entry? {
        guard let entry, now >= entry.date, now.timeIntervalSince(entry.date) <= window else { return nil }
        return entry
    }

    /// The tab a notification belongs on: Beeper, Google Chat, or All (spec SO-9).
    nonisolated static func tab(isBeeper: Bool, isGoogleChat: Bool) -> NotificationsTab {
        isBeeper ? .beeper : isGoogleChat ? .googleChat : .all
    }
}

extension NotchViewModel {
    /// A module seen open in the panel goes to the front of the module switcher (spec QS-3).
    /// Checked once the change has settled: the switchers and the settings do not count.
    func noteOpened() {
        guard isExpanded else { return }
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isExpanded, !self.isPreview, !self.isShowingOverlayPage, !self.isShowingSettings,
                      !self.isShowingNotifications
                else { return }
                ModuleHistory.shared.opened(self.currentFeature)
            }
        }
    }
}
