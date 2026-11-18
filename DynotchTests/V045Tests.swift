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
        model.select(.calendar)
        #expect(!model.canResize)
    }

    @Test func chatListGrowsWithTheWidth() {
        #expect(ClaudeChatView.sidebarWidth(for: 500) == 160)
        #expect(ClaudeChatView.sidebarWidth(for: 900) == 216)
        #expect(ClaudeChatView.sidebarWidth(for: 2000) == 260)
    }
}
