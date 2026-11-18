@testable import Dynotch
import Foundation
import Testing

/// Tray settings, badge app list, panel opacity.
struct V045Tests {
    @Test func backgroundHelpersAreNotOfferedForBadges() {
        #expect(InstalledApps.isBackgroundOnly(["LSUIElement": true]))
        #expect(InstalledApps.isBackgroundOnly(["LSUIElement": "1"]))
        #expect(InstalledApps.isBackgroundOnly(["LSBackgroundOnly": NSNumber(value: 1)]))
        #expect(!InstalledApps.isBackgroundOnly(["LSUIElement": false]))
        #expect(!InstalledApps.isBackgroundOnly(["CFBundleName": "Mail"]))
        #expect(!InstalledApps.isBackgroundOnly(nil))
        #expect(InstalledApps.coreServicesAllowed.contains("com.apple.finder"))
    }

    @MainActor @Test func panelOpacityStaysBetweenFortyAndHundredPercent() throws {
        let defaults = try #require(UserDefaults(suiteName: "V045Tests-\(UUID().uuidString)"))
        #expect(AppSettings(defaults: defaults).panelOpacity == 1)
        defaults.set(0.1, forKey: "panelOpacity")
        #expect(AppSettings(defaults: defaults).panelOpacity == 0.4)
        let settings = AppSettings(defaults: defaults)
        settings.panelOpacity = 0.7
        #expect(abs(AppSettings(defaults: defaults).panelOpacity - 0.7) < 0.0001)
    }

    @MainActor @Test func trayKnowsItsOwnFolder() {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("V045Tray-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "V045Tray-\(UUID().uuidString)") ?? .standard
        #expect(TrayStore(defaults: defaults, folder: folder).folder == folder)
    }
}

/// Resizing modules (spec RS-1…RS-5).
@MainActor
struct ResizeTests {
    private func model() throws -> (NotchViewModel, ModuleSizes) {
        let defaults = try #require(UserDefaults(suiteName: "V045Resize-\(UUID().uuidString)"))
        let settings = AppSettings(defaults: defaults)
        let sizes = ModuleSizes(defaults: defaults)
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663, auxiliaryRightWidth: 663, menuBarHeight: 32
        )
        let model = NotchViewModel(settings: settings, geometry: geometry, screenName: "Built-in", moduleSizes: sizes)
        model.select(.claudeChat)
        model.setExpanded(true)
        model.select(.claudeChat)
        return (model, sizes)
    }

    @Test func dragResizesWithinBoundsAndIsKeptPerDisplay() throws {
        let (model, sizes) = try model()
        let normal = model.openSize
        model.resize(to: CGSize(width: normal.width + 200, height: normal.height + 100))
        #expect(model.openSize == CGSize(width: normal.width + 200, height: normal.height + 100))
        model.endResize()
        #expect(sizes.size(of: .claudeChat, on: "Built-in") == CGSize(width: normal.width + 200, height: normal.height + 100))
        #expect(sizes.size(of: .claudeChat, on: "Other") == nil)
        // Never smaller than normal, never larger than the display allows.
        model.resize(to: CGSize(width: 10, height: 10_000))
        #expect(model.openSize.width == normal.width)
        #expect(model.openSize.height == model.geometry.maxModuleSize.height)
        model.endResize()
        model.resetModuleSize()
        #expect(model.openSize == normal)
        #expect(model.geometry.windowSize.width >= model.geometry.maxModuleSize.width)
    }

    @Test func onlyResizableModulesWithTheSettingOn() throws {
        let (model, _) = try model()
        #expect(model.canResize)
        model.settings.resizableModules = false
        #expect(!model.canResize)
        model.settings.resizableModules = true
        // Every module, a new one too (spec RS-6); not the settings.
        #expect(ModuleSizes.resizable == Set(FeatureID.allCases))
        model.select(.calendar)
        #expect(model.canResize)
        model.setShowingSettings(true)
        #expect(!model.canResize)
    }

    @Test func largeViewsKeepTheirOwnSize() throws {
        let defaults = try #require(UserDefaults(suiteName: "V045Variant-\(UUID().uuidString)"))
        let sizes = ModuleSizes(defaults: defaults)
        sizes.set(CGSize(width: 1100, height: 500), of: .calendar, variant: "large", on: "A")
        #expect(sizes.size(of: .calendar, on: "A") == nil)
        #expect(ModuleSizes(defaults: defaults).size(of: .calendar, variant: "large", on: "A") == CGSize(width: 1100, height: 500))
    }

    @Test func sidebarsGrowWithTheModule() {
        #expect(Responsive.share(0.3, of: 500, in: 240...360) == 240)
        #expect(Responsive.share(0.3, of: 1000, in: 240...360) == 300)
        #expect(NotesWorkspaceView.sidebarWidth(for: 2000) == 320)
        #expect(CalendarFullView.monthWidth(for: 960) == 288)
        #expect(BeeperStyle.listWidth(for: 700) == 240)
    }

    @Test func chatListGrowsWithTheWidth() {
        #expect(ClaudeChatView.sidebarWidth(for: 500) == 160)
        #expect(ClaudeChatView.sidebarWidth(for: 900) == 216)
        #expect(ClaudeChatView.sidebarWidth(for: 2000) == 260)
    }
}

/// The tasks counter beside the notch (spec R-10, R-11).
struct TaskIndicatorTests {
    private func task(_ id: String, due: Date?, hasTime: Bool = false) -> ReminderItem {
        ReminderItem(id: id, title: id, listID: "l", due: due, dueHasTime: hasTime, priority: 0, isCompleted: false, created: nil)
    }

    @Test func todaysTasksFirstOtherwiseAllOpen() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10)))
        let yesterday = now.addingTimeInterval(-86_400)
        let nextWeek = now.addingTimeInterval(7 * 86_400)
        let today = [task("a", due: now), task("b", due: yesterday), task("c", due: nextWeek), task("d", due: nil)]
        #expect(TaskIndicatorLogic.count(today, now: now, calendar: calendar) == TaskCount(count: 2, isToday: true))
        let later = [task("c", due: nextWeek), task("d", due: nil)]
        #expect(TaskIndicatorLogic.count(later, now: now, calendar: calendar) == TaskCount(count: 2, isToday: false))
        #expect(TaskIndicatorLogic.count([], now: now, calendar: calendar) == nil)
    }

    @Test func hiddenCounterComesBackWhenTimeIsUpOrATaskArrives() {
        let now = Date()
        let until = now.addingTimeInterval(3600)
        #expect(!TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: ["a"], openIDs: ["a"], now: now))
        #expect(!TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: ["a", "b"], openIDs: ["a"], now: now))
        #expect(TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: ["a"], openIDs: ["a", "new"], now: now))
        #expect(TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: ["a"], openIDs: ["a"], now: until))
    }

    @Test func snoozeTimes() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 22, minute: 30)))
        #expect(TaskSnooze.halfHour.until(from: now, calendar: calendar) == now.addingTimeInterval(1800))
        let tomorrow = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 19)))
        #expect(TaskSnooze.tomorrow.until(from: now, calendar: calendar) == tomorrow)
    }

    @Test func tasksSitAtTheFarRightWithoutAnIcon() {
        let items = IndicatorItem.items(meetings: [], usage: nil, tasks: TaskCount(count: 3, isToday: true))
        #expect(items.map(\.id) == ["tasks"])
        let layout = IndicatorLayout(items: items)
        #expect(layout.iconSlots.isEmpty)
        #expect(layout.leftWidth == 0)
        #expect(layout.rightWidth > 0)
    }
}

/// Chat badges open their tab (spec BP-12, GC-5).
struct ChatBadgeTests {
    @Test func chatBadgesOpenTheirTab() {
        let beeper = BadgeApp(bundleID: "com.automattic.beeper.desktop", name: "Beeper Desktop", isEnabled: true, icon: .app)
        let chat = BadgeApp(bundleID: "com.apple.Safari.WebApp.940A", name: "Google Chat", isEnabled: true, icon: .app)
        let mail = BadgeApp(bundleID: "com.apple.mail", name: "Mail", isEnabled: true, icon: .app)
        #expect(BadgeApp.chatTab(for: beeper) == .beeper)
        #expect(BadgeApp.chatTab(for: chat) == .googleChat)
        #expect(BadgeApp.chatTab(for: mail) == nil)
    }
}
