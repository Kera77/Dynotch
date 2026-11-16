import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// Behaviours added in 0.26.
@MainActor
struct V026Tests {
    private func device(_ id: String, _ level: Int, charging: Bool = false, kind: BatteryDevice.Kind = .mouse) -> BatteryDevice {
        BatteryDevice(id: id, name: id, kind: kind, level: level, isCharging: charging)
    }

    // MARK: - Batteries (spec BT-1…BT-3)

    @Test func hidDevicesAreReadFromTheRegistry() throws {
        let entries: [[String: Any]] = [
            ["Product": "Peter’s Magic Keyboard", "BatteryPercent": 95, "BatteryStatusFlags": 0],
            ["Product": "Péter’s Magic Mouse", "BatteryPercent": 28, "BatteryStatusFlags": 3],
            ["Product": "Peter's Magic Trackpad", "BatteryPercent": 134],
            ["BatteryPercent": 50]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: entries, format: .xml, options: 0)
        let devices = BatteryParser.hidDevices(fromPlist: data)
        #expect(devices.map(\.kind) == [.keyboard, .mouse, .trackpad])
        #expect(devices.map(\.level) == [95, 28, 100])
        #expect(devices[1].isCharging)
        #expect(BatteryParser.hidDevices(fromPlist: Data("x".utf8)).isEmpty)
    }

    @Test func earbudsGiveTheLowerBudAndTheCase() {
        let json = #"""
        {"SPBluetoothDataType":[{"device_connected":[
          {"Peter's AirPods Pro":{"device_batteryLevelCase":"80%","device_batteryLevelLeft":"100%",
            "device_batteryLevelRight":"64%","device_minorType":"Headphones"}},
          {"Peter's Magic Trackpad":{"device_minorType":"Magic Trackpad"}},
          {"Speaker":{"device_batteryLevelMain":"15%","device_minorType":"Speaker"}}
        ],"device_not_connected":[{"Old":{"device_batteryLevelMain":"5%"}}]}]}
        """#
        let devices = BatteryParser.bluetoothDevices(fromJSON: Data(json.utf8))
        #expect(devices.map(\.name) == ["Peter's AirPods Pro", "Peter's AirPods Pro Case", "Speaker"])
        #expect(devices.map(\.level) == [64, 80, 15])
        #expect(devices.map(\.kind) == [.earbuds, .earbudsCase, .other])
    }

    @Test func aDeviceBothToolsReportAppearsOnce() {
        let hid = [BatteryDevice(id: "hid:x", name: "Peter’s Magic Mouse", kind: .mouse, level: 30)]
        let bluetooth = [
            BatteryDevice(id: "bt:x", name: "Peter's Magic Mouse", kind: .mouse, level: 31),
            BatteryDevice(id: "bt:y", name: "AirPods", kind: .earbuds, level: 90)
        ]
        let merged = BatteryParser.merged(mac: device("mac", 78, kind: .mac), hid: hid, bluetooth: bluetooth)
        #expect(merged.map(\.id) == ["mac", "hid:x", "bt:y"])
        #expect(BatteryDevice.Kind.detect("AirPods Max") == .headphones)
        #expect(BatteryDevice.Kind.detect("Sony Headphones") == .headphones)
    }

    /// Spec BT-3: below 20 % a warning shows until it is closed; it returns after a recharge.
    @Test func lowBatteriesWarnUntilDismissed() {
        let name = "V026Tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let service = BatteryService(settings: AppSettings(defaults: defaults))

        service.apply([device("mouse", 19), device("keys", 20), device("pad", 5, charging: true), device("buds", 8)])
        #expect(service.warnings.map(\.id) == ["buds", "mouse"])

        service.dismissWarning(for: device("mouse", 19))
        #expect(service.warnings.map(\.id) == ["buds"])
        // Still low, or switched off for a while: stays hidden.
        service.apply([device("mouse", 12), device("buds", 8)])
        service.apply([device("buds", 8)])
        service.apply([device("mouse", 25), device("buds", 8)])
        #expect(service.warnings.map(\.id) == ["buds"])
        // Recharged, then low again: warns again.
        service.apply([device("mouse", 90), device("buds", 8)])
        service.apply([device("mouse", 15), device("buds", 8)])
        #expect(service.warnings.map(\.id) == ["buds", "mouse"])
    }

    @Test func aLowBatteryHasItsOwnIconAndPlace() {
        let mouse = device("mouse", 12)
        let items = IndicatorItem.items(meetings: [], usage: nil, working: true, lowBatteries: [mouse, device("keys", 9)])
        #expect(items.map(\.id) == ["claude-working", "battery-mouse", "battery-keys"])
        #expect(IndicatorItem.iconSlots(for: items) == [0, 1, 2])
        #expect(!IndicatorItem.battery(mouse).isClaude)
        let layout = IndicatorLayout(items: items)
        #expect(layout.slotWidths == [IndicatorLayout.ringSlotWidth, IndicatorLayout.batterySlotWidth, IndicatorLayout.batterySlotWidth])
    }

    // MARK: - Crisp on non-Retina displays

    /// Even widths keep the row beside the notch on whole pixels.
    @Test func widthsBesideTheNotchAreEven() {
        let widths: [CGFloat] = [
            NotchGeometry.virtualNotchWidth, IndicatorLayout.slotWidth, IndicatorLayout.ringSlotWidth,
            IndicatorLayout.batterySlotWidth, IndicatorLayout.iconWidth, IndicatorLayout.spacing, IndicatorLayout.padding,
            IndicatorLayout.separatorWidth, IndicatorLayout.badgeSpacing, LevelRing.size,
            BatteryItemWidths.one, BatteryItemWidths.three
        ]
        #expect(widths.allSatisfy { $0.truncatingRemainder(dividingBy: 2) == 0 })
        let layout = IndicatorLayout(
            slotWidths: [IndicatorLayout.slotWidth, IndicatorLayout.ringSlotWidth], badgeWidths: [BatteryItemWidths.one]
        )
        #expect(layout.horizontalOffset == layout.horizontalOffset.rounded())
    }

    private enum BatteryItemWidths {
        static let one = BadgeItem.width(text: "7")
        static let three = BadgeItem.width(text: "99+")
    }

    // MARK: - System notices (spec E-2c)

    @Test func everySystemNoticeBelongsToSystemSettings() {
        #expect(NotificationApp.isSystem(identifier: "com.apple.btmnotificationagent", hasApplication: false))
        #expect(NotificationApp.isSystem(identifier: "com.apple.somedaemon", hasApplication: false))
        #expect(NotificationApp.isSystem(identifier: "_system_center_:anything", hasApplication: false))
        #expect(NotificationApp.isSystem(identifier: NotificationApp.systemGroupID, hasApplication: false))
        // Apple's apps are apps; other vendors' identifiers are never system notices.
        #expect(!NotificationApp.isSystem(identifier: "com.apple.mail", hasApplication: true))
        #expect(!NotificationApp.isSystem(identifier: "com.vendor.tool", hasApplication: false))

        let name = "V026Tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: defaults)
        let service = NotificationService(settings: settings)
        var daemon = NotificationApp(identifier: "com.apple.somedaemon", name: "System Settings", url: nil, icon: nil)
        daemon.isSystem = true
        #expect(service.isEnabled(daemon))
        settings.setNotificationApp(NotificationApp.systemGroupID, enabled: false)
        #expect(!service.isEnabled(daemon))
    }

    // MARK: - Claude finished names the right project (spec CN-4)

    @Test func theNoticeNamesTheProjectThatWasWorkedOn() {
        let text = [
            #"{"name":"Edit","input":{"file_path":"/Users/x/Dynotch/Sources/A.swift"}}"#,
            #"{"name":"Bash","input":{"command":"cd /Users/x/Dynotch && git status"}}"#,
            #"{"name":"Read","input":{"file_path":"/Users/x/Other/notes.md"}}"#,
            #"{"name":"Read","input":{"file_path":"/tmp/scratch/out.txt"}}"#
        ].joined(separator: "\n")
        let paths = ClaudeTranscript.workedPaths(in: text)
        #expect(paths.contains("/Users/x/Dynotch/Sources"))
        #expect(paths.contains("/Users/x/Dynotch"))
        let repositories: Set<String> = ["/Users/x/Dynotch", "/Users/x/Other"]
        #expect(ClaudeTranscript.project(amongPaths: paths) { repositories.contains($0) } == "Dynotch")
        #expect(ClaudeTranscript.project(amongPaths: ["/tmp/a"]) { _ in false } == nil)
        #expect(ClaudeTranscript.project(amongPaths: []) { _ in true } == nil)
    }
}
