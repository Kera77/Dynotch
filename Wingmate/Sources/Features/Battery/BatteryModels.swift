import Foundation

/// A device with a battery: the Mac itself or something connected to it (spec BT-1).
struct BatteryDevice: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case mac
        case keyboard
        case mouse
        case trackpad
        case earbuds
        case earbudsCase
        case headphones
        case other

        /// SF Symbols, best first; the first one this macOS has is used.
        var symbols: [String] {
            switch self {
            case .mac: ["laptopcomputer"]
            case .keyboard: ["keyboard.fill", "keyboard"]
            case .mouse: ["magicmouse.fill", "computermouse.fill", "cursorarrow"]
            case .trackpad: ["rectangle.and.hand.point.up.left.fill", "hand.point.up.left.fill"]
            case .earbuds: ["airpodspro", "airpods", "earbuds"]
            case .earbudsCase: ["airpodspro.chargingcase.wireless.fill", "airpods.chargingcase.fill", "earbuds.case.fill"]
            case .headphones: ["headphones"]
            case .other: ["battery.50percent"]
            }
        }

        /// From the device's name or the type Bluetooth reports.
        static func detect(_ text: String) -> Kind {
            let words = text.lowercased()
            if words.contains("keyboard") { return .keyboard }
            if words.contains("trackpad") { return .trackpad }
            if words.contains("mouse") { return .mouse }
            if words.contains("airpods max") || words.contains("headphones") && !words.contains("airpods") { return .headphones }
            if words.contains("airpods") || words.contains("buds") || words.contains("headphones") || words.contains("headset") {
                return .earbuds
            }
            return .other
        }
    }

    let id: String
    let name: String
    let kind: Kind
    /// 0…100
    let level: Int
    var isCharging = false

    var isLow: Bool { isLow(below: BatteryRules.lowLevel) }

    /// At or under the device's own threshold and not charging; 0 never warns (spec BT-7).
    func isLow(below threshold: Int) -> Bool { threshold > 0 && level <= threshold && !isCharging }
}

/// When a battery counts as low, and which warnings stay hidden (spec BT-3, BT-7).
enum BatteryRules {
    static let lowLevel = 20
    /// A dismissed warning comes back only after the device was charged this far above its threshold.
    static let rearmMargin = 10
    static var rearmLevel: Int { lowLevel + rearmMargin }
    /// The thresholds offered in Settings; 0 is Off (spec BT-7).
    static let thresholdChoices = [0, 5, 10, 15, 20, 25, 30, 40, 50]

    /// The low devices to warn about, lowest first, without the dismissed ones.
    static func warnings(
        for devices: [BatteryDevice], dismissed: Set<String>, threshold: (String) -> Int = { _ in lowLevel }
    ) -> [BatteryDevice] {
        devices.filter { $0.isLow(below: threshold($0.id)) && !dismissed.contains($0.id) }.sorted { $0.level < $1.level }
    }

    /// Dismissals that still hold: the device is gone for now, or has not been recharged.
    static func dismissedStillHolding(
        _ dismissed: Set<String>, devices: [BatteryDevice], threshold: (String) -> Int = { _ in lowLevel }
    ) -> Set<String> {
        dismissed.filter { id in
            guard let device = devices.first(where: { $0.id == id }) else { return true }
            return device.level < threshold(id) + rearmMargin && !device.isCharging
        }
    }

    /// "Peter’s Mouse" and "Peter's Mouse" are the same device.
    static func key(forName name: String) -> String {
        name.lowercased().replacingOccurrences(of: "’", with: "'").trimmingCharacters(in: .whitespaces)
    }
}

/// Reads what the system tools print about batteries (spec BT-2).
enum BatteryParser {
    /// `ioreg -r -k BatteryPercent -a`: Magic Keyboard, Mouse, Trackpad and other HID devices.
    static func hidDevices(fromPlist data: Data) -> [BatteryDevice] {
        guard let entries = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else { return [] }
        return entries.compactMap { entry in
            guard let name = entry["Product"] as? String, let level = (entry["BatteryPercent"] as? NSNumber)?.intValue else { return nil }
            let flags = (entry["BatteryStatusFlags"] as? NSNumber)?.intValue ?? 0
            return BatteryDevice(
                id: "hid:" + BatteryRules.key(forName: name), name: name, kind: .detect(name),
                level: min(max(level, 0), 100), isCharging: flags & 0x3 != 0
            )
        }
    }

    private static func percent(_ value: Any?) -> Int? {
        guard let text = value as? String else { return nil }
        return Int(text.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
    }

    /// `system_profiler SPBluetoothDataType -json`: AirPods and other devices that report
    /// their level over Bluetooth. Earbuds give the lower of the two buds, and their case.
    static func bluetoothDevices(fromJSON data: Data) -> [BatteryDevice] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return [] }
        var devices: [BatteryDevice] = []
        for section in sections {
            for entry in section["device_connected"] as? [[String: Any]] ?? [] {
                for (name, value) in entry {
                    guard let info = value as? [String: Any] else { continue }
                    let type = info["device_minorType"] as? String ?? ""
                    let key = BatteryRules.key(forName: name)
                    let buds = [percent(info["device_batteryLevelLeft"]), percent(info["device_batteryLevelRight"])].compactMap { $0 }
                    if let level = buds.min() {
                        devices.append(BatteryDevice(id: "bt:" + key, name: name, kind: .detect(name + " " + type), level: level))
                    } else if let level = percent(info["device_batteryLevelMain"]) {
                        devices.append(BatteryDevice(id: "bt:" + key, name: name, kind: .detect(name + " " + type), level: level))
                    }
                    if let level = percent(info["device_batteryLevelCase"]) {
                        devices.append(BatteryDevice(id: "bt-case:" + key, name: name + " Case", kind: .earbudsCase, level: level))
                    }
                }
            }
        }
        return devices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The Mac first, then the others; a device both tools report appears once.
    static func merged(mac: BatteryDevice?, hid: [BatteryDevice], bluetooth: [BatteryDevice]) -> [BatteryDevice] {
        let known = Set(hid.map { BatteryRules.key(forName: $0.name) })
        let extra = bluetooth.filter { !known.contains(BatteryRules.key(forName: $0.name)) }
        return [mac].compactMap { $0 } + hid + extra
    }
}
