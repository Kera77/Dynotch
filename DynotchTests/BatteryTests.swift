import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// Batteries: devices, low warnings, history and the Mac's own battery (spec BT-1…BT-7).
@MainActor
struct BatteryTests {
    private func device(_ id: String, _ level: Int, charging: Bool = false, kind: BatteryDevice.Kind = .mouse) -> BatteryDevice {
        BatteryDevice(id: id, name: id, kind: kind, level: level, isCharging: charging)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        return calendar
    }

    /// 2026-11-18 10:00 Budapest
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10)) ?? Date()
    }

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
        let name = "BatteryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let service = BatteryService(settings: AppSettings(defaults: defaults), defaults: defaults)

        service.apply([device("mouse", 19), device("keys", 21), device("pad", 5, charging: true), device("buds", 8)])
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

    /// Spec BT-7: each device warns at its own level; Off never warns; the re-arm follows the level.
    @Test func eachDeviceHasItsOwnLowLevel() {
        let name = "BatteryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let service = BatteryService(settings: AppSettings(defaults: defaults), defaults: defaults)
        service.setThreshold(40, for: "mouse")
        service.setThreshold(0, for: "buds")

        service.apply([device("mouse", 40), device("buds", 3), device("keys", 20)])
        #expect(service.warnings.map(\.id) == ["keys", "mouse"])
        #expect(service.known["mouse"] == "mouse")
        service.dismissWarning(for: device("mouse", 40))
        service.apply([device("mouse", 45), device("buds", 3), device("keys", 20)])
        service.apply([device("mouse", 38), device("buds", 3), device("keys", 20)])
        #expect(service.warnings.map(\.id) == ["keys"])
        service.apply([device("mouse", 50), device("buds", 3), device("keys", 20)])
        service.apply([device("mouse", 38), device("buds", 3), device("keys", 20)])
        #expect(service.warnings.map(\.id) == ["keys", "mouse"])
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

    @Test func estimateFromTheDaysDischarge() throws {
        let samples = [
            BatterySample(date: now.addingTimeInterval(-10 * 3600), level: 80),
            BatterySample(date: now, level: 30)
        ]
        // 50 % in 10 hours: the remaining 30 % lasts 6 hours.
        let left = try #require(BatteryHistory.estimate(from: samples, now: now))
        #expect(abs(left - 6 * 3600) < 1)
        #expect(BatteryHistory.estimateText(left) == "about 6 hours left")
    }

    @Test func noEstimateWhileCharging() {
        let samples = [BatterySample(date: now.addingTimeInterval(-3600), level: 20), BatterySample(date: now, level: 40)]
        #expect(BatteryHistory.estimate(from: samples, now: now) == nil)
    }

    @MainActor @Test func historyKeepsAWeekOnDisk() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("battery-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let history = BatteryHistory(file: file)
        let mouse = BatteryDevice(id: "mouse", name: "Mouse", kind: .mouse, level: 50)
        history.record([mouse], at: now.addingTimeInterval(-8 * 86_400))
        history.record([mouse], at: now)
        #expect(history.samples["mouse"]?.count == 1)
        #expect(BatteryHistory(file: file).samples["mouse"]?.count == 1)
    }

    @Test func earbudsShowEachSideAndTheCase() throws {
        let json = Data("""
        {"SPBluetoothDataType":[{"device_connected":[{"Peter's AirPods Pro":{"device_batteryLevelCase":"74%",
        "device_batteryLevelLeft":"90%","device_batteryLevelRight":"89%"}},{"Mouse":{"device_batteryLevelMain":"15%"}}]}]}
        """.utf8)
        let airPods = DeviceBattery.structuredLevels(named: "Peter's AirPods Pro", json: json)
        #expect(airPods.map(\.part) == [.left, .right, .caseBattery])
        #expect(airPods.map(\.percent) == [90, 89, 74])
        #expect(DeviceBattery.structuredLevels(named: "Mouse", json: json) == [DeviceLevel(part: .main, percent: 15)])
        #expect(DeviceBattery.structuredLevels(named: "Unknown", json: json).isEmpty)
    }

    @Test func batteryDetailsComeFromItsRegistryEntry() {
        var battery = MacBattery(level: 80, isCharging: false, isOnPower: false)
        battery.addDetails([
            "CycleCount": 123, "AppleRawMaxCapacity": 4500, "DesignCapacity": 5000, "Voltage": 12000,
            "Amperage": Int(bitPattern: UInt(UInt64.max - 999))
        ])
        #expect(battery.cycles == 123)
        #expect(battery.health == 0.9)
        // -1000 mA at 12 V: 12 W going out.
        #expect(battery.watts == -12)
    }
}
