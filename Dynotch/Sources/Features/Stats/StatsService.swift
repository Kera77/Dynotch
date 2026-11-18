import AppKit
import Combine

/// What the closed notch shows of the stats (spec SY-7).
enum StatsIndicatorMode: String, CaseIterable, Sendable {
    case off
    case cpu
    case network

    var title: String {
        switch self {
        case .off: "Nothing"
        case .cpu: "CPU"
        case .network: "Network speed"
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
}

/// Problems worth a dot beside the closed notch (spec SY-8).
enum StatsWarnings {
    static let lowDisk: Int64 = 10_000_000_000

    nonisolated static func warnings(
        memoryPressure: Int?, diskFree: Int64?, diskTotal: Int64?, thermal: ProcessInfo.ThermalState
    ) -> [String] {
        var found: [String] = []
        if let memoryPressure, memoryPressure >= 2 {
            found.append(memoryPressure >= 4 ? "Memory is critically low" : "Memory is running low")
        }
        if let diskFree, let diskTotal, diskTotal > 0, diskFree < lowDisk || Double(diskFree) / Double(diskTotal) < 0.05 {
            found.append("The disk is almost full")
        }
        if thermal == .serious || thermal == .critical {
            found.append("The Mac is slowing down to cool off")
        }
        return found
    }
}

/// The closed notch's part: whether a value or a warning shows. Its own object, so the notch is
/// not redrawn with every reading (spec SY-7, SY-8).
@MainActor
final class StatsIndicator: ObservableObject {
    @Published fileprivate(set) var mode = StatsIndicatorMode.off
    @Published fileprivate(set) var warnings: [String] = []

    var isShown: Bool { mode != .off || !warnings.isEmpty }
}

/// Reads the system's numbers (spec SY-1…SY-8): every second while the module is open, every two
/// for the value beside the notch, otherwise only now and then for the warnings.
@MainActor
final class StatsService: ObservableObject {
    @Published private(set) var snapshot = StatsSnapshot()
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var downloadHistory: [Double] = []
    @Published private(set) var uploadHistory: [Double] = []
    @Published private(set) var processes: [ProcessUsage] = []
    @Published var sortsByMemory = false { didSet { if oldValue != sortsByMemory { rankProcesses() } } }
    @Published var mode: StatsIndicatorMode {
        didSet {
            defaults.set(mode.rawValue, forKey: Self.modeKey)
            indicator.mode = settings.isEnabled(.stats) ? mode : .off
            schedule()
        }
    }
    let indicator = StatsIndicator()

    static let historyLength = 90
    private static let modeKey = "statsIndicator"
    private let settings: AppSettings
    private let defaults: UserDefaults
    private var timer: Timer?
    private var interval: TimeInterval = 0
    private var isVisible = false
    private var settingsObserver: AnyCancellable?
    private var ticks: SystemReadings.CPUTicks?
    private var network: (SystemReadings.Network, Date)?
    private var diskCounters: (SystemReadings.Disk, Date)?
    private var processSample: ProcessReadings.Sample?
    private var processCPU: [pid_t: Double] = [:]
    private var readings = 0

    init(settings: AppSettings, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
        mode = defaults.string(forKey: Self.modeKey).flatMap(StatsIndicatorMode.init(rawValue:)) ?? .off
    }

    func start() {
        settingsObserver = settings.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.applyEnabled() } }
        }
        applyEnabled()
    }

    /// The module is on screen: read every second, with the processes.
    func setVisible(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
        if !visible { processSample = nil }
        schedule()
        if visible { read() }
    }

    private func applyEnabled() {
        let isOn = settings.isEnabled(.stats)
        indicator.mode = isOn ? mode : .off
        if !isOn { indicator.warnings = [] }
        schedule()
    }

    private func schedule() {
        let wanted: TimeInterval = !settings.isEnabled(.stats) ? 0 : isVisible ? 1 : mode != .off ? 2 : 30
        guard wanted != interval else { return }
        interval = wanted
        timer?.invalidate()
        timer = nil
        guard wanted > 0 else { return }
        let timer = Timer(timeInterval: wanted, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.read() }
        }
        timer.tolerance = wanted * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        read()
    }

    private func read() {
        readings += 1
        var next = snapshot
        let now = Date()
        if let newTicks = SystemReadings.cpuTicks() {
            if let ticks { next.cpu = SystemReadings.cpuLoad(from: ticks, to: newTicks) }
            ticks = newTicks
        }
        next.memory = SystemReadings.memory()
        readNetwork(into: &next, now: now)
        readDisk(into: &next, now: now)
        if next.battery == nil || readings.isMultiple(of: 5) { next.battery = MacBattery.read() }
        snapshot = next
        cpuHistory = Array((cpuHistory + [next.cpu]).suffix(Self.historyLength))
        downloadHistory = Array((downloadHistory + [next.download]).suffix(Self.historyLength))
        uploadHistory = Array((uploadHistory + [next.upload]).suffix(Self.historyLength))
        let warnings = StatsWarnings.warnings(
            memoryPressure: next.memory?.pressure, diskFree: next.disk?.free, diskTotal: next.disk?.total,
            thermal: ProcessInfo.processInfo.thermalState
        )
        if indicator.warnings != warnings { indicator.warnings = warnings }
        if isVisible { readProcesses() }
    }

    private func readNetwork(into next: inout StatsSnapshot, now: Date) {
        let counters = SystemReadings.network()
        if let (old, date) = network {
            let seconds = now.timeIntervalSince(date)
            next.download = SystemReadings.rate(from: old.received, to: counters.received, seconds: seconds)
            next.upload = SystemReadings.rate(from: old.sent, to: counters.sent, seconds: seconds)
        }
        next.address = counters.address
        network = (counters, now)
    }

    private func readDisk(into next: inout StatsSnapshot, now: Date) {
        let disk = SystemReadings.disk()
        if let (old, date) = diskCounters, disk.read >= old.read, disk.written >= old.written {
            let seconds = max(now.timeIntervalSince(date), 0.001)
            next.diskRead = Double(disk.read - old.read) / seconds
            next.diskWrite = Double(disk.written - old.written) / seconds
        }
        next.disk = disk
        diskCounters = (disk, now)
    }

    private func readProcesses() {
        let sample = ProcessReadings.sample()
        if let processSample { processCPU = ProcessReadings.cpu(from: processSample, to: sample) }
        processSample = sample
        rankProcesses()
    }

    private func rankProcesses() {
        guard let processSample else { return }
        processes = ProcessReadings.top(6, byMemory: sortsByMemory, cpu: processCPU, memory: processSample.memory)
    }

    func quit(_ process: ProcessUsage) {
        ProcessReadings.quit(process)
        processes.removeAll { $0.id == process.id }
    }
}
