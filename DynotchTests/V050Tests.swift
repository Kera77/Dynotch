@testable import Dynotch
import Foundation
import Testing

/// Shortcut-opened modules are not remembered; the tasks counter drops down its tasks.
@MainActor
struct V050Tests {
    private func makeModel() -> NotchViewModel {
        let name = "V050Tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        return NotchViewModel(settings: AppSettings(defaults: defaults), geometry: geometry, screenName: "Test")
    }

    @Test func shortcutModuleIsNotRememberedForHover() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.calendar)
        model.select(.calculator, remember: false)
        #expect(model.currentFeature == .calculator)
        model.setExpanded(false)
        model.setExpanded(true)
        #expect(model.currentFeature == .calendar)
    }

    private func task(_ id: String, due: Date?) -> ReminderItem {
        ReminderItem(id: id, title: id, listID: "l", due: due, dueHasTime: true, priority: 0, isCompleted: false, created: nil)
    }

    @Test func dropDownListsTheCountedTasks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10)))
        let items = [task("later", due: now.addingTimeInterval(5 * 86_400)), task("noon", due: now.addingTimeInterval(7200)),
                     task("early", due: now.addingTimeInterval(-3600))]
        #expect(TaskIndicatorLogic.listed(items, now: now, calendar: calendar).map(\.id) == ["early", "noon"])
        let notToday = [task("b", due: nil), task("a", due: now.addingTimeInterval(3 * 86_400))]
        #expect(TaskIndicatorLogic.listed(notToday, now: now, calendar: calendar).map(\.id) == ["a", "b"])
    }

    @Test func dropDownHeightFollowsTheTasksUpToSix() {
        let base = IndicatorLayout.labelHeight
        #expect(IndicatorItem.tasks(TaskCount(count: 2, isToday: true)).labelHeight == base + 2 * 22 + 6)
        #expect(IndicatorItem.tasks(TaskCount(count: 20, isToday: false)).labelHeight == base + 6 * 22 + 6)
    }

    @Test func beeperTabIsWideOnlyWithItsList() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.notifications)
        model.notificationsTab = .beeper
        model.beeperListOpen = true
        #expect(model.openSize == model.geometry.chatPanelSize)
        model.beeperListOpen = false
        #expect(model.openSize != model.geometry.chatPanelSize)
        model.notificationsTab = .googleChat
        let googleChat = model.openSize
        model.notificationsTab = .beeper
        #expect(model.openSize == googleChat)
    }
}
