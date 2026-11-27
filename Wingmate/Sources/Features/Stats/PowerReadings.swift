import Foundation
import IOKit
import IOKit.ps

/// The Mac's own battery (spec SY-5).
struct MacBattery: Equatable, Sendable {
    var level: Int
    var isCharging: Bool
    var isOnPower: Bool
    /// Minutes to empty or to full; nil while macOS is still estimating.
    var minutesLeft: Int?
    /// Watts going in (positive) or out (negative).
    var watts: Double?
    /// Full charge now against when new, 0…1.
    var health: Double?
    var cycles: Int?

    static func read() -> MacBattery? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        let source = list.lazy
            .compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
            .first { ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType }
        guard let source else { return nil }
        let isCharging = source[kIOPSIsChargingKey] as? Bool ?? false
        let minutes = (isCharging ? source[kIOPSTimeToFullChargeKey] : source[kIOPSTimeToEmptyKey]) as? Int
        var battery = MacBattery(
            level: source[kIOPSCurrentCapacityKey] as? Int ?? 0, isCharging: isCharging,
            isOnPower: (source[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
            minutesLeft: minutes.flatMap { $0 > 0 ? $0 : nil }
        )
        battery.addDetails(smartBattery())
        return battery
    }

    /// Health, cycles and power from the battery's own registry entry.
    mutating func addDetails(_ properties: [String: Any]) {
        cycles = properties["CycleCount"] as? Int
        if let maximum = properties["AppleRawMaxCapacity"] as? Int, let design = properties["DesignCapacity"] as? Int, design > 0 {
            health = min(Double(maximum) / Double(design), 1)
        }
        if let millivolts = properties["Voltage"] as? Int, let raw = properties["Amperage"] as? Int {
            // Some Macs store the signed current as an unsigned 64-bit number.
            let milliamps = Int(Int32(truncatingIfNeeded: raw))
            watts = Double(millivolts) * Double(milliamps) / 1_000_000
        }
    }

    private static func smartBattery() -> [String: Any] {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return [:] }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return [:] }
        return properties?.takeRetainedValue() as? [String: Any] ?? [:]
    }
}
