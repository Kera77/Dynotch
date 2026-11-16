import AppKit
import Combine
import IOKit.ps

/// Battery levels of the Mac and of the devices connected to it (spec BT-1…BT-3).
@MainActor
final class BatteryService: ObservableObject {
    @Published private(set) var devices: [BatteryDevice] = []
    /// Devices whose warning was closed with the X; kept until they are recharged.
    @Published private(set) var dismissed: Set<String> = []
    @Published private(set) var lastUpdated: Date?

    private let settings: AppSettings
    private var timer: Timer?
    private var isReading = false
    private static let interval: TimeInterval = 120

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// The low devices shown beside the notch (spec BT-3).
    var warnings: [BatteryDevice] {
        settings.isEnabled(.battery) ? BatteryRules.warnings(for: devices, dismissed: dismissed) : []
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
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

    func apply(_ found: [BatteryDevice]) {
        if found != devices { devices = found }
        let holding = BatteryRules.dismissedStillHolding(dismissed, devices: found)
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return Data() }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }
}
