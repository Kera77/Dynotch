@testable import Dynotch
import Foundation
import Testing

/// v0.94: the latest notification's module on hover (SO-9, SO-10), the module switcher (QS-3, QS-5).
struct V094Tests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func notice(_ feature: FeatureID, minutesAgo: Double = 1, tab: NotificationsTab? = nil) -> RecentNotice.Entry {
        RecentNotice.Entry(feature: feature, tab: tab, file: nil, id: "x", date: now.addingTimeInterval(-minutesAgo * 60))
    }

    @Test func latestNotificationLeadsEveryOpeningAfterTheMeeting() {
        var context = SmartContext(battery: "mouse")
        context.notice = notice(.notifications, tab: .beeper)
        // Not once: a used key does not stop it (SO-9).
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: ["notice:x"])?.feature == .notifications)
        context.meeting = "m1"
        #expect(SmartOpening.choose(context, isOn: { _ in true }, used: [])?.feature == .calendar)
        #expect(SmartOpening.choose(context, isOn: { $0 != .notice }, used: ["meeting:m1"])?.feature == .battery)
    }

    @Test func noticeWindowEnds() {
        #expect(SmartOpening.liveNotice(notice(.tray, minutesAgo: 4), now: now, window: 300)?.feature == .tray)
        #expect(SmartOpening.liveNotice(notice(.tray, minutesAgo: 6), now: now, window: 300) == nil)
        #expect(SmartOpening.liveNotice(nil, now: now, window: 300) == nil)
    }

    @Test func notificationTabBySource() {
        #expect(SmartOpening.tab(isBeeper: true, isGoogleChat: false) == .beeper)
        #expect(SmartOpening.tab(isBeeper: false, isGoogleChat: true) == .googleChat)
        #expect(SmartOpening.tab(isBeeper: false, isGoogleChat: false) == .all)
    }

    @MainActor @Test func historyPutsTheLatestFirst() throws {
        let defaults = try #require(UserDefaults(suiteName: "V094Tests.history"))
        defaults.removePersistentDomain(forName: "V094Tests.history")
        let history = ModuleHistory(defaults: defaults)
        history.opened(.notes)
        history.opened(.calendar)
        history.opened(.notes)
        #expect(ModuleHistory(defaults: defaults).recent == [.notes, .calendar])
    }
}
