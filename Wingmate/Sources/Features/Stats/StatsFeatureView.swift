import SwiftUI

/// The System Stats module (spec SY-1…SY-7): tiles for CPU, memory, network, disk and battery,
/// and the busiest processes with a Quit button.
struct StatsFeatureView: View {
    @Bindable var service: StatsService
    let isActive: Bool
    /// Off when the Options sit beside the System | Batteries tabs instead (spec SY-13).
    var showsOptions = true
    @State private var width: CGFloat = 720

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if showsOptions {
                    HStack {
                        Spacer()
                        StatsOptionsMenu(options: service.options)
                    }
                }
                ScrollView(.vertical) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
                        cpuCard
                        memoryCard
                        networkCard
                        speedCard
                        diskCard
                        if let battery = service.snapshot.battery { batteryCard(battery) }
                    }
                }
                .scrollIndicators(.never)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            StatsProcessList(service: service)
                .frame(width: Responsive.share(0.36, of: width, in: 220...340))
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .readWidth($width)
        .onAppear { service.setVisible(isActive) }
        .onChange(of: isActive) { _, active in service.setVisible(active) }
        .onDisappear { service.setVisible(false) }
    }

    private var cpuCard: some View {
        StatsCard(title: "CPU", symbol: "cpu", value: StatsFormat.percent(service.snapshot.cpu)) {
            StatsSparkline(values: service.cpuHistory, top: 1, color: Theme.blue).frame(height: 34)
        }
    }

    private var memoryCard: some View {
        let memory = service.snapshot.memory
        let fraction = memory.map { Double($0.used) / Double(max($0.total, 1)) } ?? 0
        let color: Color = switch memory?.pressure ?? 1 {
        case 4...: Theme.red
        case 2...: .orange
        default: Theme.green
        }
        return StatsCard(title: "Memory", symbol: "memorychip", value: StatsFormat.percent(fraction)) {
            StatsBar(fraction: fraction, color: color)
            if let memory {
                StatsDetail("\(StatsFormat.bytes(Double(memory.used))) of \(StatsFormat.bytes(Double(memory.total)))")
                StatsDetail("Swap \(StatsFormat.bytes(Double(memory.swapUsed)))")
            }
        }
    }

    /// The local IP and the traffic graph; the speeds have their own tile (spec SY-13).
    private var networkCard: some View {
        StatsCard(title: "Network", symbol: "network", value: service.snapshot.address ?? "–") {
            ZStack {
                StatsSparkline(values: service.downloadHistory, color: Theme.blue)
                StatsSparkline(values: service.uploadHistory, color: Theme.green.opacity(0.8))
            }
            .frame(height: 34)
            StatsDetail("Local IP · Wi-Fi and Ethernet")
        }
    }

    /// Download and upload speed in a sixth tile (spec SY-13).
    private var speedCard: some View {
        let snapshot = service.snapshot
        return StatsCard(title: "Speed", symbol: "arrow.up.arrow.down", value: "") {
            speedRow("arrow.down", "Download", StatsFormat.rate(snapshot.download), Theme.blue)
            speedRow("arrow.up", "Upload", StatsFormat.rate(snapshot.upload), Theme.green)
        }
    }

    private func speedRow(_ symbol: String, _ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.notch(size: 10, weight: .bold)).foregroundStyle(color)
            Text(title).font(.notch(size: 11)).foregroundStyle(Color.white.level(0.6))
            Spacer(minLength: 4)
            Text(value)
                .font(.notch(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private var diskCard: some View {
        let disk = service.snapshot.disk
        let used = disk.map { 1 - Double($0.free) / Double(max($0.total, 1)) } ?? 0
        return StatsCard(title: "Disk", symbol: "internaldrive", value: disk.map { StatsFormat.bytes(Double($0.free)) + " free" } ?? "–") {
            StatsBar(fraction: used, color: used > 0.95 ? Theme.red : Theme.blue)
            HStack(spacing: 6) {
                StatsDetail("Read \(StatsFormat.rate(service.snapshot.diskRead)) · Write \(StatsFormat.rate(service.snapshot.diskWrite))")
                Spacer(minLength: 4)
                // The Cleaner opens in place of the Stats (spec TT-8).
                CleanButton()
            }
        }
    }

    private func batteryCard(_ battery: MacBattery) -> some View {
        let state = battery.isCharging ? "Charging" : battery.isOnPower ? "On power" : "On battery"
        let left = battery.minutesLeft.map { " · " + StatsFormat.minutes($0) + (battery.isCharging ? " to full" : " left") } ?? ""
        let details = [
            battery.watts.map { String(format: "%.1f W", abs($0)) },
            battery.health.map { "Health " + StatsFormat.percent($0) },
            battery.cycles.map { "\($0) cycles" }
        ].compactMap { $0 }
        return StatsCard(title: "Battery", symbol: battery.isCharging ? "battery.100percent.bolt" : "battery.75percent",
                         value: "\(battery.level)%") {
            StatsBar(fraction: Double(battery.level) / 100, color: battery.level <= 20 ? Theme.red : Theme.green)
            StatsDetail(state + left)
            StatsDetail(details.joined(separator: " · "))
        }
    }
}

/// The busiest processes, by CPU or memory; Quit asks once more (spec SY-6).
struct StatsProcessList: View {
    @Bindable var service: StatsService
    @State private var confirming: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Top processes").font(.notch(size: 11, weight: .semibold)).foregroundStyle(Color.white.level(0.6))
                Spacer()
                Picker("Sort", selection: $service.sortsByMemory) {
                    Text("CPU").tag(false)
                    Text("Memory").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .fixedSize()
            }
            ForEach(service.processes) { row($0) }
            if service.processes.isEmpty {
                StatsDetail("Reading…")
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Theme.fill))
    }

    private func row(_ process: ProcessUsage) -> some View {
        StatsProcessRow(process: process, byMemory: service.sortsByMemory, isConfirming: confirming == process.id) {
            if confirming == process.id {
                service.quit(process)
                confirming = nil
            } else {
                confirming = process.id
            }
        }
    }
}

/// One busy app: its icon, name, CPU or memory, and the X that turns into Quit (spec SY-6, SY-14).
struct StatsProcessRow: View {
    let process: ProcessUsage
    let byMemory: Bool
    let isConfirming: Bool
    let tapX: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            if let app = process.appPath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app)).resizable().frame(width: 16, height: 16)
            } else {
                Image(systemName: "gearshape").font(.notch(size: 11)).foregroundStyle(Color.white.level(0.5)).frame(width: 16)
            }
            Text(process.name).font(.notch(size: 11)).foregroundStyle(.white).lineLimit(1)
            Spacer(minLength: 4)
            Text(byMemory ? StatsFormat.bytes(Double(process.memory)) : StatsFormat.percent(process.cpu))
                .font(.notch(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color.white.level(0.7))
            Button(action: tapX) {
                Text(isConfirming ? "Quit" : "✕")
                    .font(.notch(size: 10, weight: .bold))
                    .foregroundStyle(isConfirming ? .white : Color.white.level(0.6))
                    .padding(.horizontal, isConfirming ? 7 : 0)
                    .frame(minWidth: 20, minHeight: 18)
                    .background(Capsule().fill(isConfirming ? Theme.red : Color.white.level(0.1)))
            }
            .buttonStyle(.notch)
            .help(isConfirming ? "Click again to quit \(process.name)" : "Quit \(process.name)")
        }
        .frame(height: Self.height)
    }

    static let height: CGFloat = 22
}

/// What shows beside the notch, which alerts are on, and the swap limit (spec SY-7…SY-9).
struct StatsOptionsMenu: View {
    @Bindable var options: StatsOptions

    var body: some View {
        Menu {
            Section("Beside the notch") {
                ForEach(StatsValue.allCases) { value in
                    Toggle(value.title, isOn: Binding(get: { options.isShown(value) }, set: { options.setShown(value, $0) }))
                }
            }
            Section("Alerts") {
                ForEach(StatsAlert.allCases) { alert in
                    Toggle(alert.title, isOn: Binding(get: { options.isOn(alert) }, set: { options.setOn(alert, $0) }))
                }
            }
            Picker("Notify When Swap Is Above", selection: $options.swapLimit) {
                Text("Never").tag(Int?.none)
                ForEach(StatsOptions.swapChoices, id: \.self) { Text("\($0) GB").tag(Int?.some($0)) }
            }
        } label: {
            Label("Options", systemImage: "slider.horizontal.3")
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.level(0.75))
        }
        .menuStyle(.button)
        .buttonStyle(.notch)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("What the closed notch shows, and the alerts")
    }
}
