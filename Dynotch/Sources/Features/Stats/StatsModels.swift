import Foundation
import Observation

/// The values the closed notch can show of the stats, any of them (spec SY-7).
enum StatsValue: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case memory
    case network

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .network: "Network speed"
        }
    }
}

/// Problems that put a red dot beside the notch, each can be turned off (spec SY-8, SY-9).
enum StatsAlert: String, CaseIterable, Identifiable, Sendable {
    case memory
    case disk
    case heat
    case swap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .memory: "Memory running low"
        case .disk: "Disk almost full"
        case .heat: "Mac slowing down to cool off"
        case .swap: "Swap above the limit"
        }
    }
}

/// One reading of everything the module shows (spec SY-1…SY-5).
struct StatsSnapshot: Equatable, Sendable {
    var cpu = 0.0
    var memory: SystemReadings.Memory?
    /// Bytes per second.
    var download = 0.0
    var upload = 0.0
    var address: String?
    var disk: SystemReadings.Disk?
    var diskRead = 0.0
    var diskWrite = 0.0
    var battery: MacBattery?

    var memoryShare: Double {
        memory.map { Double($0.used) / Double(max($0.total, 1)) } ?? 0
    }
}

/// What a reading says is wrong (spec SY-8, SY-9).
enum StatsWarnings {
    static let lowDisk: Int64 = 10_000_000_000
    static let gigabyte: UInt64 = 1_073_741_824

    struct Reading: Sendable {
        var memoryPressure: Int?
        var diskFree: Int64?
        var diskTotal: Int64?
        var thermal: ProcessInfo.ThermalState = .nominal
        var swapUsed: UInt64 = 0
        /// Gigabytes; nil: no swap limit.
        var swapLimit: Int?
    }

    nonisolated static func warnings(_ reading: Reading, off: Set<StatsAlert> = []) -> [String] {
        var found: [String] = []
        if !off.contains(.memory), let pressure = reading.memoryPressure, pressure >= 2 {
            found.append(pressure >= 4 ? "Memory is critically low" : "Memory is running low")
        }
        if !off.contains(.disk), let free = reading.diskFree, let total = reading.diskTotal, total > 0,
           free < lowDisk || Double(free) / Double(total) < 0.05 {
            found.append("The disk is almost full")
        }
        if !off.contains(.heat), reading.thermal == .serious || reading.thermal == .critical {
            found.append("The Mac is slowing down to cool off")
        }
        if !off.contains(.swap), isOverSwap(reading) {
            found.append("Swap is above \(reading.swapLimit ?? 0) GB")
        }
        return found
    }

    nonisolated static func isOverSwap(_ reading: Reading) -> Bool {
        guard let limit = reading.swapLimit, limit > 0 else { return false }
        return reading.swapUsed > UInt64(limit) * gigabyte
    }
}

/// The stats' choices (spec SY-7, SY-9), kept in the defaults.
@MainActor
@Observable
final class StatsOptions {
    /// Shown beside the closed notch.
    private(set) var shownValues: Set<StatsValue> {
        didSet { defaults.set(shownValues.map(\.rawValue).sorted(), forKey: Self.valuesKey) }
    }
    private(set) var alertsOff: Set<StatsAlert> {
        didSet { defaults.set(alertsOff.map(\.rawValue).sorted(), forKey: Self.alertsKey) }
    }
    /// Gigabytes of swap that bring a notification; nil: none.
    var swapLimit: Int? {
        didSet { defaults.set(swapLimit ?? 0, forKey: Self.swapKey) }
    }

    static let swapChoices = [1, 2, 4, 8, 16, 32]
    private static let valuesKey = "statsValues", alertsKey = "statsAlertsOff", swapKey = "statsSwapLimit"
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        shownValues = Set((defaults.stringArray(forKey: Self.valuesKey) ?? []).compactMap(StatsValue.init(rawValue:)))
        alertsOff = Set((defaults.stringArray(forKey: Self.alertsKey) ?? []).compactMap(StatsAlert.init(rawValue:)))
        let swap = defaults.integer(forKey: Self.swapKey)
        swapLimit = swap > 0 ? swap : nil
    }

    func isShown(_ value: StatsValue) -> Bool { shownValues.contains(value) }

    func setShown(_ value: StatsValue, _ shown: Bool) {
        if shown { shownValues.insert(value) } else { shownValues.remove(value) }
    }

    func isOn(_ alert: StatsAlert) -> Bool { !alertsOff.contains(alert) }

    func setOn(_ alert: StatsAlert, _ isOn: Bool) {
        if isOn { alertsOff.remove(alert) } else { alertsOff.insert(alert) }
    }
}
