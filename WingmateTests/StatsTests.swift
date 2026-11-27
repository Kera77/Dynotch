import Foundation
import Testing
@testable import Wingmate

/// The System module: readings, processes and warnings.
struct StatsTests {
    @Test func cpuLoadComesFromTwoReadings() {
        let old = SystemReadings.CPUTicks(busy: 100, total: 1000)
        let new = SystemReadings.CPUTicks(busy: 150, total: 1100)
        #expect(SystemReadings.cpuLoad(from: old, to: new) == 0.5)
        #expect(SystemReadings.cpuLoad(from: new, to: old) == 0)
    }

    @Test func networkRatesSurviveTheCounterWrapping() {
        #expect(SystemReadings.rate(from: 1000, to: 3000, seconds: 2) == 1000)
        let wrapped = SystemReadings.rate(from: UInt64(UInt32.max) - 999, to: 1000, seconds: 1)
        #expect(wrapped == 2000)
    }

    @Test func processCPUIsTimeUsedPerSecond() {
        let start = Date(timeIntervalSince1970: 0)
        let old = ProcessReadings.Sample(cpuTime: [1: 0, 2: 5_000_000_000], memory: [:], date: start)
        let new = ProcessReadings.Sample(
            cpuTime: [1: 1_000_000_000, 2: 5_000_000_000, 3: 9], memory: [:], date: start.addingTimeInterval(2)
        )
        let cpu = ProcessReadings.cpu(from: old, to: new)
        #expect(cpu[1] == 0.5)
        #expect(cpu[2] == 0)
        // A new process has no earlier reading yet.
        #expect(cpu[3] == nil)
    }

    @Test func helpersAreCountedWithTheirApp() {
        #expect(ProcessReadings.appBundle(of: "/Applications/Zen.app/Contents/MacOS/zen") == "/Applications/Zen.app")
        let helper = "/Applications/Zen.app/Contents/Frameworks/plugin-container.app/Contents/MacOS/plugin-container"
        #expect(ProcessReadings.appBundle(of: helper) == "/Applications/Zen.app")
        #expect(ProcessReadings.appBundle(of: "/usr/libexec/logd") == nil)
        let groups = ProcessReadings.grouped(
            cpu: [1: 0.2, 2: 0.3, 3: 0.1], memory: [1: 100, 2: 200, 3: 50],
            paths: [1: "/Applications/Zen.app/Contents/MacOS/zen", 2: helper, 3: "/usr/libexec/logd"]
        )
        let zen = groups.first { $0.key == "/Applications/Zen.app" }
        #expect(zen?.pids == [1, 2])
        #expect(abs((zen?.cpu ?? 0) - 0.5) < 0.0001)
        #expect(zen?.memory == 300)
        #expect(groups.contains { $0.key == "pid:3" })
        #expect(StatsService.smoothed(old: [1: 1.0], new: [1: 0.0, 2: 0.5]) == [1: 0.4, 2: 0.5])
    }

    @Test func aHiddenWarningComesBackOnlyAfterItCleared() {
        var dismissed: Set<String> = ["Memory is running low"]
        #expect(StatsService.shown(["Memory is running low"], dismissed: &dismissed).isEmpty)
        // A new kind shows at once.
        #expect(StatsService.shown(["Memory is running low", "The disk is almost full"], dismissed: &dismissed)
            == ["The disk is almost full"])
        // Cleared: forgotten, so it shows when it comes back.
        #expect(StatsService.shown([], dismissed: &dismissed).isEmpty)
        #expect(StatsService.shown(["Memory is running low"], dismissed: &dismissed) == ["Memory is running low"])
    }

    @Test func warningsCoverMemoryDiskHeatAndSwap() {
        typealias Reading = StatsWarnings.Reading
        let calm = Reading(memoryPressure: 1, diskFree: 200_000_000_000, diskTotal: 500_000_000_000)
        #expect(StatsWarnings.warnings(calm).isEmpty)
        let gigabyte = StatsWarnings.gigabyte
        let bad = Reading(
            memoryPressure: 4, diskFree: 5_000_000_000, diskTotal: 500_000_000_000, thermal: .serious,
            swapUsed: 5 * gigabyte, swapLimit: 4
        )
        #expect(StatsWarnings.warnings(bad) == [
            "Memory is critically low", "The disk is almost full", "The Mac is slowing down to cool off", "Swap is above 4 GB"
        ])
        // Each alert can be turned off (spec SY-9).
        #expect(StatsWarnings.warnings(bad, off: [.memory, .disk, .heat]) == ["Swap is above 4 GB"])
        #expect(!StatsWarnings.isOverSwap(Reading(swapUsed: 3 * gigabyte, swapLimit: 4)))
        #expect(!StatsWarnings.isOverSwap(Reading(swapUsed: 30 * gigabyte, swapLimit: nil)))
    }

    @Test func shortRatesFitBesideTheNotch() {
        #expect(StatsFormat.shortRate(500) == "0K")
        #expect(StatsFormat.shortRate(830_000) == "830K")
        #expect(StatsFormat.shortRate(1_250_000) == "1.2M" || StatsFormat.shortRate(1_250_000) == "1.3M")
        #expect(StatsFormat.shortRate(42_000_000) == "42M")
    }

    @Test func theSystemReadersGiveSensibleNumbers() throws {
        let memory = try #require(SystemReadings.memory())
        #expect(memory.used > 0 && memory.used < memory.total)
        #expect([1, 2, 4].contains(memory.pressure))
        #expect(SystemReadings.cpuTicks().map { $0.total > $0.busy } == true)
        let disk = SystemReadings.disk()
        #expect(disk.total > disk.free && disk.free > 0)
        #expect(ProcessReadings.sample().cpuTime.count > 10)
        _ = SystemReadings.network()
        if let battery = MacBattery.read() { #expect((0...100).contains(battery.level)) }
    }
}
