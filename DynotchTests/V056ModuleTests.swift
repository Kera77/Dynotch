@testable import Dynotch
import Foundation
import Testing

struct MusicModuleTests {
    private let fields = [
        "playing", "Song", "Artist", "Album", "https://i.scdn.co/image/abc", "215000", "61.5", "true", "false", "64",
        "spotify:track:1"
    ]

    @Test func spotifysAnswerIsRead() throws {
        let playing = try #require(NowPlaying.parse(fields))
        #expect(playing.isPlaying)
        #expect(playing.title == "Song")
        #expect(playing.duration == 215)
        #expect(playing.position == 61.5)
        #expect(playing.isShuffling && !playing.isRepeating)
        #expect(playing.volume == 64)
        #expect(playing.artworkURL?.host == "i.scdn.co")
    }

    @Test func stoppedOrBrokenAnswersGiveNothing() {
        #expect(NowPlaying.parse(["stopped"]) == nil)
        var paused = fields
        paused[0] = "paused"
        paused[4] = "http://example.com/x.jpg"
        let parsed = NowPlaying.parse(paused)
        #expect(parsed?.isPlaying == false)
        // Only secure cover addresses are loaded.
        #expect(parsed?.artworkURL == nil)
    }

    @Test func theCoversColourIsItsMostCommonLivelyHue() {
        // 3 red pixels, 1 grey, 1 blue: red wins, made bright enough for the black notch.
        let pixels: [UInt8] = [200, 20, 20, 255, 200, 20, 20, 255, 190, 30, 30, 255, 128, 128, 128, 255, 20, 20, 200, 255]
        let color = ArtworkColor.dominant(rgba: pixels)
        #expect(color.red > 0.7 && color.green < 0.3 && color.blue < 0.3)
        // A grey cover gives the soft white.
        #expect(ArtworkColor.dominant(rgba: [120, 120, 120, 255, 30, 30, 30, 255]) == ArtworkColor.fallback)
    }

    @Test func theProgressBarMapsClicksToSeconds() {
        #expect(MusicProgressBar.seconds(at: 50, width: 200, duration: 240) == 60)
        #expect(MusicProgressBar.seconds(at: -10, width: 200, duration: 240) == 0)
        #expect(MusicProgressBar.seconds(at: 500, width: 200, duration: 240) == 240)
        #expect(MusicProgressBar.time(125.9) == "2:05")
    }

    @Test @MainActor func theCoverSitsNextToTheNotchAndOpensTheModule() {
        let glance = MusicIndicator.Glance(
            trackID: "1", title: "Song", artist: "A", isPlaying: true, artwork: nil, tint: ArtworkColor.fallback
        )
        let items = IndicatorItem.items(
            meetings: [], usage: nil, tasks: TaskCount(count: 2, isToday: true), music: glance, stats: true
        )
        #expect(items.map(\.id) == ["music", "stats", "tasks"])
        #expect(items[0].opensModule == .music)
        #expect(items[1].opensModule == .stats)
        #expect(items[2].opensModule == nil)
    }
}

struct StatsModuleTests {
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

    @Test func warningsCoverMemoryDiskAndHeat() {
        #expect(StatsWarnings.warnings(memoryPressure: 1, diskFree: 200_000_000_000, diskTotal: 500_000_000_000, thermal: .nominal)
            .isEmpty)
        let all = StatsWarnings.warnings(memoryPressure: 4, diskFree: 5_000_000_000, diskTotal: 500_000_000_000, thermal: .serious)
        #expect(all == ["Memory is critically low", "The disk is almost full", "The Mac is slowing down to cool off"])
        #expect(StatsWarnings.warnings(memoryPressure: 2, diskFree: nil, diskTotal: nil, thermal: .fair) == ["Memory is running low"])
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
