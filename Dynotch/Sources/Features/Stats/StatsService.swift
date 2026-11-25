import AppKit
import Observation

/// The closed notch's part: whether a value or a warning shows. Its own object, so the notch is
/// not redrawn with every reading (spec SY-7, SY-8).
@MainActor
@Observable
final class StatsIndicator {
    fileprivate(set) var values: [StatsValue] = []
    fileprivate(set) var warnings: [String] = []

    var isShown: Bool { !values.isEmpty || !warnings.isEmpty }
    /// For the row: how many values the slot holds, nil when it is not shown.
    var slotValues: Int? { isShown ? values.count : nil }
}

/// Reads the system's numbers (spec SY-1…SY-8): every second while the module is open, every two
/// for the value beside the notch, otherwise only now and then for the warnings.
@MainActor
@Observable
final class StatsService {
    private(set) var snapshot = StatsSnapshot()
    private(set) var cpuHistory: [Double] = []
    private(set) var downloadHistory: [Double] = []
    private(set) var uploadHistory: [Double] = []
    private(set) var processes: [ProcessUsage] = []
    var sortsByMemory = false { didSet { if oldValue != sortsByMemory { rankProcesses() } } }
    /// What shows beside the notch and the alerts: its own object, so its menu is not rebuilt
    /// with every reading (spec SY-7, SY-9).
    let options: StatsOptions
    /// Sends Dynotch's own notification (spec SY-9).
    @ObservationIgnored var notify: (String, String) -> Void = { _, _ in }
    /// Whether Settings › Notifications › Dynotch alerts turned a warning's kind off (spec SY-12).
    @ObservationIgnored var isAlertOff: (StatsAlert) -> Bool = { _ in false }
    @ObservationIgnored private var swapNotified = false
    /// Warnings hidden with the X, until they clear (spec SY-10).
    @ObservationIgnored private var dismissed: Set<String> = []
    @ObservationIgnored private var active: [String] = []
    let indicator = StatsIndicator()

    static let historyLength = 90
    private let settings: AppSettings
    private let defaults: UserDefaults
    @ObservationIgnored private var timer: Poller?
    @ObservationIgnored private var interval: TimeInterval = 0
    @ObservationIgnored private var isVisible = false
    /// System tiles on the Home are on screen: every two seconds, without the processes (spec HT-9).
    @ObservationIgnored private var tilesVisible = false
    @ObservationIgnored private var settingsObserver: ChangeObservation?
    @ObservationIgnored private var ticks: SystemReadings.CPUTicks?
    @ObservationIgnored private var network: (SystemReadings.Network, Date)?
    @ObservationIgnored private var diskCounters: (SystemReadings.Disk, Date)?
    @ObservationIgnored private var processSample: ProcessReadings.Sample?
    @ObservationIgnored private var processCPU: [pid_t: Double] = [:]
    @ObservationIgnored private var readings = 0

    init(settings: AppSettings, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
        options = StatsOptions(defaults: defaults)
    }

    func start() {
        settingsObserver = observeChanges { [settings, options] in
            _ = settings.isEnabled(.stats)
            _ = options.shownValues
        } onChange: { [weak self] in
            self?.applyEnabled()
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

    func setTilesVisible(_ visible: Bool) {
        guard tilesVisible != visible else { return }
        tilesVisible = visible
        schedule()
    }

    private func applyEnabled() {
        let isOn = settings.isEnabled(.stats)
        let values = isOn ? StatsValue.allCases.filter(options.shownValues.contains) : []
        if indicator.values != values { indicator.values = values }
        if !isOn { indicator.warnings = [] }
        schedule()
    }

    private func schedule() {
        let wanted: TimeInterval = !settings.isEnabled(.stats) ? 0 : isVisible ? 1 : tilesVisible || !options.shownValues.isEmpty ? 2 : 30
        guard wanted != interval else { return }
        interval = wanted
        timer?.invalidate()
        timer = nil
        guard wanted > 0 else { return }
        // The open module's 1 s readings stay quick; the background ones slow down (spec RF-10).
        let settings = settings
        self.timer = Poller.start(
            every: wanted, tolerance: 0.1, scalesWithPower: !isVisible, isActive: { settings.isEnabled(.stats) },
            action: { [weak self] in self?.read() }
        )
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
        checkWarnings(next)
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
        if let processSample {
            processCPU = Self.smoothed(old: processCPU, new: ProcessReadings.cpu(from: processSample, to: sample))
        }
        processSample = sample
        rankProcesses()
    }

    private func rankProcesses() {
        guard let processSample else { return }
        processes = ProcessReadings.top(6, byMemory: sortsByMemory, cpu: processCPU, sample: processSample)
    }

    private func checkWarnings(_ next: StatsSnapshot) {
        let reading = StatsWarnings.Reading(
            memoryPressure: next.memory?.pressure, diskFree: next.disk?.free, diskTotal: next.disk?.total,
            thermal: ProcessInfo.processInfo.thermalState, swapUsed: next.memory?.swapUsed ?? 0, swapLimit: options.swapLimit
        )
        let off = options.alertsOff.union(StatsAlert.allCases.filter(isAlertOff))
        active = StatsWarnings.warnings(reading, off: off)
        let warnings = Self.shown(active, dismissed: &dismissed)
        if indicator.warnings != warnings { indicator.warnings = warnings }
        // One notification per crossing of the swap limit (spec SY-9).
        let isOver = StatsWarnings.isOverSwap(reading)
        if isOver, !swapNotified, !off.contains(.swap), let limit = options.swapLimit {
            notify("Swap is above \(limit) GB", "\(StatsFormat.bytes(Double(reading.swapUsed))) of swap in use")
        }
        swapNotified = isOver
    }

    /// A little of the earlier reading stays, so the busiest ones don't jump around (spec SY-6).
    nonisolated static func smoothed(old: [pid_t: Double], new: [pid_t: Double]) -> [pid_t: Double] {
        new.reduce(into: [:]) { result, entry in
            result[entry.key] = old[entry.key].map { $0 * 0.4 + entry.value * 0.6 } ?? entry.value
        }
    }

    /// The warnings not hidden; a hidden one that cleared is forgotten, so it shows when it comes
    /// back (spec SY-10).
    nonisolated static func shown(_ active: [String], dismissed: inout Set<String>) -> [String] {
        dismissed.formIntersection(active)
        return active.filter { !dismissed.contains($0) }
    }

    func dismissWarnings() {
        dismissed.formUnion(active)
        indicator.warnings = Self.shown(active, dismissed: &dismissed)
    }

    func quit(_ process: ProcessUsage) {
        ProcessReadings.quit(process)
        processes.removeAll { $0.id == process.id }
    }
}
