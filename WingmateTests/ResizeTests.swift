import Foundation
import Testing
@testable import Wingmate

/// Resizing modules (spec RS-1…RS-5).
@MainActor
struct ResizeTests {
    private func model() throws -> (NotchViewModel, ModuleSizes) {
        let defaults = try #require(UserDefaults(suiteName: "ResizeTests-\(UUID().uuidString)"))
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
        let defaults = try #require(UserDefaults(suiteName: "ResizeTests-Variant-\(UUID().uuidString)"))
        let sizes = ModuleSizes(defaults: defaults)
        sizes.set(CGSize(width: 1100, height: 500), of: .calendar, variant: "large", on: "A")
        #expect(sizes.size(of: .calendar, on: "A") == nil)
        #expect(ModuleSizes(defaults: defaults).size(of: .calendar, variant: "large", on: "A") == CGSize(width: 1100, height: 500))
    }

    @Test func tabsShareTheModulesSize() throws {
        let (model, sizes) = try model()
        model.select(.calendar)
        let tabs = try #require(model.settings.mergedTabs(for: .calendar))
        #expect(tabs == [.calendar, .weather])
        // The same size on every tab (spec RS-7).
        let normal = model.openSize
        model.select(.weather)
        #expect(model.openSize == normal)
        // Resized on one tab: kept for the whole module.
        model.resize(to: CGSize(width: normal.width + 120, height: normal.height + 60))
        model.endResize()
        #expect(sizes.size(of: .calendar, on: "Built-in") == CGSize(width: normal.width + 120, height: normal.height + 60))
        #expect(sizes.size(of: .weather, on: "Built-in") == nil)
        model.select(.calendar)
        #expect(model.openSize == CGSize(width: normal.width + 120, height: normal.height + 60))
        // A tab's size from before RS-7 stands in for the module.
        model.resetModuleSize()
        sizes.set(CGSize(width: normal.width + 40, height: normal.height + 30), of: .weather, on: "Built-in")
        #expect(model.openSize == CGSize(width: normal.width + 40, height: normal.height + 30))
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
