import AppKit
import IOKit.ps
import Observation

/// Battery levels of the Mac and of the devices connected to it (spec BT-1…BT-3).
@MainActor
@Observable
final class BatteryService {
    private(set) var devices: [BatteryDevice] = []
    /// Devices whose warning was closed with the X; kept until they are recharged.
    private(set) var dismissed: Set<String> = []
    private(set) var lastUpdated: Date?
    /// Per device: the level at which the notch warns, when it differs from 20 % (spec BT-7).
    private(set) var thresholds: [String: Int]
    /// Every device seen so far (id → name), so Settings lists it while it is away (spec BT-7).
    private(set) var known: [String: String]
    private let defaults: UserDefaults

    private let settings: AppSettings
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isReading = false
    /// system_profiler is heavy: every five minutes (spec BT-1b).
    private static let interval: TimeInterval = 300

    init(settings: AppSettings, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
        thresholds = defaults.dictionary(forKey: Self.thresholdsKey) as? [String: Int] ?? [:]
        known = defaults.dictionary(forKey: Self.knownKey) as? [String: String] ?? [:]
    }

    private static let thresholdsKey = "batteryLowThresholds"
    private static let knownKey = "batteryKnownDevices"

    func threshold(for id: String) -> Int { thresholds[id] ?? BatteryRules.lowLevel }

    func setThreshold(_ value: Int, for id: String) {
        thresholds[id] = value == BatteryRules.lowLevel ? nil : value
        defaults.set(thresholds, forKey: Self.thresholdsKey)
    }

    /// The low devices shown beside the notch (spec BT-3).
    var warnings: [BatteryDevice] {
        settings.isEnabled(.battery) ? BatteryRules.warnings(for: devices, dismissed: dismissed, threshold: threshold(for:)) : []
    }

    func start() {
        guard timer == nil else { return }
        self.timer = RepeatingTimer.start(every: Self.interval) { [weak self] in self?.refresh() }
        refresh()
    }

    func refresh() {
        guard !isReading, settings.isEnabled(.battery) else { return }
        isReading = true
        Task { [weak self] in
            let found = await Task.detached { BatteryReader.read() }.value
            self?.isReading = false
            self?.apply(found)
        }
    }

    /// Levels over the last week (spec BT-4).
    let history = BatteryHistory()
    /// Tells when a device finished charging (spec BT-5).
    @ObservationIgnored var onCharged: (BatteryDevice) -> Void = { _ in }

    func apply(_ found: [BatteryDevice]) {
        // Charging reached full since the last reading.
        for device in found where device.level >= 100 {
            if let before = devices.first(where: { $0.id == device.id }), before.level < 100, before.isCharging || device.isCharging {
                onCharged(device)
            }
        }
        history.record(found)
        if found != devices { devices = found }
        var names = known
        for device in found { names[device.id] = device.name }
        if names != known {
            known = names
            defaults.set(names, forKey: Self.knownKey)
        }
        let holding = BatteryRules.dismissedStillHolding(dismissed, devices: found, threshold: threshold(for:))
        if holding != dismissed { dismissed = holding }
        lastUpdated = Date()
    }

    func dismissWarning(for device: BatteryDevice) {
        dismissed.insert(device.id)
    }
}

/// Runs the system tools; called off the main thread.
enum BatteryReader {
    static func read() -> [BatteryDevice] {
        let hid = BatteryParser.hidDevices(fromPlist: run("/usr/sbin/ioreg", ["-r", "-k", "BatteryPercent", "-a"]))
        let bluetooth = BatteryParser.bluetoothDevices(fromJSON: run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"]))
        return BatteryParser.merged(mac: internalBattery(), hid: hid, bluetooth: bluetooth)
    }

    /// The Mac's own battery, if it has one.
    static func internalBattery() -> BatteryDevice? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let capacity = description[kIOPSMaxCapacityKey] as? Int, capacity > 0
            else { continue }
            let onPower = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return BatteryDevice(
                id: "mac", name: Host.current().localizedName ?? "This Mac", kind: .mac,
                level: min(max(current * 100 / capacity, 0), 100), isCharging: onPower
            )
        }
        return nil
    }

    private static func run(_ path: String, _ arguments: [String]) -> Data {
        ProcessRunner.run(path, arguments)?.output ?? Data()
    }

}
