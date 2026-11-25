import SwiftUI

/// The System tiles: each reading on its own, and the top processes (spec HT-14).
struct StatsTileContent: View {
    let tile: HomeTile
    var stats: StatsService
    let size: TileSize

    var body: some View {
        let snapshot = stats.snapshot
        switch tile {
        case .cpu:
            VStack(alignment: .leading, spacing: 4) {
                TileValueView(title: "CPU", value: StatsFormat.percent(snapshot.cpu), color: StatsSlot.color(for: snapshot.cpu))
                StatsSparkline(values: stats.cpuHistory, top: 1, color: Theme.blue).frame(height: 18)
            }
        case .memory:
            TileValueView(
                title: "Memory", value: StatsFormat.percent(snapshot.memoryShare),
                detail: snapshot.memory.map { "\(StatsFormat.bytes(Double($0.used))) of \(StatsFormat.bytes(Double($0.total)))" },
                color: StatsSlot.color(for: snapshot.memoryShare)
            )
        case .swap:
            TileValueView(title: "Swap", value: snapshot.memory.map { StatsFormat.bytes(Double($0.swapUsed)) } ?? "—")
        case .network:
            TileValueView(
                title: "Network", value: "↓ " + StatsFormat.shortRate(snapshot.download),
                detail: "↑ " + StatsFormat.rate(snapshot.upload)
            )
        case .disk:
            diskContent(snapshot.disk)
        case .topProcesses:
            processes
        default:
            batteryContent(snapshot.battery)
        }
    }

    private var processes: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Top processes").font(.notch(size: 10, weight: .medium)).foregroundStyle(.secondary)
            ForEach(Array(stats.processes.prefix(size.lines))) { process in
                TileRow(text: process.name, note: StatsFormat.percent(process.cpu)) { EmptyView() }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func diskContent(_ disk: SystemReadings.Disk?) -> some View {
        if let disk {
            let used = 1 - Double(disk.free) / Double(max(disk.total, 1))
            VStack(alignment: .leading, spacing: 4) {
                TileValueView(title: "Disk", value: StatsFormat.bytes(Double(disk.free)), detail: "free")
                StatsBar(fraction: used, color: StatsSlot.color(for: used))
            }
        } else {
            TileEmptyView(title: "Disk", text: "Not read yet")
        }
    }

    @ViewBuilder
    private func batteryContent(_ battery: MacBattery?) -> some View {
        if let battery {
            let state = battery.isCharging ? "Charging" : battery.isOnPower ? "On power" : "On battery"
            let left = battery.minutesLeft.map { " · " + StatsFormat.minutes($0) } ?? ""
            TileValueView(
                title: "Battery", value: "\(battery.level)%", detail: state + left,
                color: battery.level <= 20 && !battery.isOnPower ? Theme.red : .white
            )
        } else {
            TileEmptyView(title: "Battery", text: "No battery")
        }
    }
}

/// The Terminal, Tools and Info tiles (spec HT-14).
struct ToolTileContent: View {
    let tile: HomeTile
    let size: TileSize

    @Environment(\.openTilePart) private var openPart

    var body: some View {
        switch tile {
        case .terminal: terminal
        case .run: RunTileContent(settings: .shared) { openPart(.run, .terminal) }
        case .timer, .stopwatch, .pomodoro: ClockToolTileContent(tile: tile, tools: .shared)
        case .quickToggles: TogglesTileContent(toggles: .shared, settings: .shared, onlyKeepAwake: false)
        case .keepAwake: TogglesTileContent(toggles: .shared, settings: .shared, onlyKeepAwake: true)
        default: TileValueView(title: "Wingmate", value: AppInfo.version, detail: "Version")
        }
    }

    private var terminal: some View {
        let store = TerminalStore.shared
        return VStack(alignment: .leading, spacing: 2) {
            Text(store.selected?.title ?? "Terminal").font(.notch(size: 12, weight: .semibold, design: .monospaced)).lineLimit(1)
            Text(store.sessions.isEmpty ? "Click to open a shell" : TerminalWing.tabs(store.sessions.count))
                .font(.notch(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

/// Runs the command set in the settings in the Terminal (spec HT-29).
private struct RunTileContent: View {
    var settings: HomeTileSettings
    let openTerminal: () -> Void

    var body: some View {
        let command = settings.runCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        if command.isEmpty {
            TileEmptyView(title: "Run", text: "Set a command in Settings › Modules › Home")
        } else {
            HStack(alignment: .bottom) {
                TileValueView(title: "Run", value: settings.runName.isEmpty ? command : settings.runName)
                Spacer(minLength: 2)
                TileButton(symbol: "play.fill", help: "Run \(command) in the Terminal") { run(command) }
            }
        }
    }

    private func run(_ command: String) {
        let store = TerminalStore.shared
        guard let session = store.current() ?? store.newSession() else { return }
        session.view.send(txt: command + "\n")
        openTerminal()
    }
}

/// A timer, the stopwatch or the pomodoro: its time and a start or pause button (spec HT-14).
private struct ClockToolTileContent: View {
    let tile: HomeTile
    var tools: ToolsService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(alignment: .bottom) {
                TileValueView(title: title, value: value(at: context.date), detail: detail)
                Spacer(minLength: 2)
                TileButton(symbol: isRunning ? "pause.fill" : "play.fill", help: isRunning ? "Pause" : "Start", action: startOrPause)
            }
        }
    }

    private var title: String {
        switch tile {
        case .timer: tools.timers.first?.title ?? "Timer"
        case .stopwatch: "Stopwatch"
        default: "Pomodoro"
        }
    }

    private var detail: String? {
        switch tile {
        case .timer: tools.timers.isEmpty ? "Not running" : nil
        case .stopwatch: tools.stopwatch.isReset ? "Not running" : nil
        default: tools.pomodoro.phase.title
        }
    }

    private var isRunning: Bool {
        switch tile {
        case .timer: tools.timers.first.map { !$0.isPaused } ?? false
        case .stopwatch: tools.stopwatch.isRunning
        default: tools.pomodoro.isRunning
        }
    }

    private func value(at now: Date) -> String {
        switch tile {
        case .timer: ClockText.text(tools.timers.first?.remaining(at: now) ?? tools.recent.first ?? 300)
        case .stopwatch: ClockText.text(tools.stopwatch.elapsed(at: now))
        default: ClockText.text(tools.pomodoro.remaining(at: now, plan: tools.settings.plan))
        }
    }

    private func startOrPause() {
        switch tile {
        case .timer:
            if let timer = tools.timers.first {
                tools.pauseOrResume(timer.id)
            } else {
                _ = tools.startTimer(tools.recent.first ?? 300)
            }
        case .stopwatch:
            tools.startOrPauseStopwatch()
        default:
            tools.startOrPausePomodoro()
        }
    }
}

/// The quick toggles that act at once, or only Keep Awake (spec HT-14).
private struct TogglesTileContent: View {
    var toggles: QuickToggleService
    var settings: ToolsSettings
    let onlyKeepAwake: Bool

    /// Empty Trash, Eject Disks and Lock Screen stay in the Tools module, where they ask first.
    private static let skipped: Set<QuickToggle> = [.emptyTrash, .ejectDisks, .lockScreen]

    var body: some View {
        let shown: [QuickToggle] = onlyKeepAwake ? [.keepAwake] : settings.shownToggles.filter { !Self.skipped.contains($0) }.prefix(5).map { $0 }
        VStack(alignment: .leading, spacing: 4) {
            Text(onlyKeepAwake ? "Keep Awake" : "Quick toggles").font(.notch(size: 10, weight: .medium)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(shown) { toggle in
                    let isOn = toggles.isOn(toggle)
                    Button { _ = toggles.toggle(toggle) } label: {
                        Image(systemName: toggle.symbol(isOn: isOn))
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(isOn ? Theme.blue : Theme.selectedFill))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .help(toggle.title)
                    .accessibilityLabel(toggle.title)
                }
            }
        }
    }
}
