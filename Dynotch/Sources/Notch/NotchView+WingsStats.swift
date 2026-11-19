import SwiftUI

// MARK: - DyNotch Wings: Stats and Reminders, v0.75 (spec PV-16, PV-18)

extension NotchView {
    // MARK: Stats (spec PV-16)

    /// The Mac first, then the other devices.
    private var wingsDevices: [BatteryDevice] {
        battery.devices.filter { $0.kind == .mac } + battery.devices.filter { $0.kind != .mac }
    }

    /// How many devices fit on the left before the wings would pass two thirds of the display.
    private var wingsDevicesFitting: Int {
        max(Int(geometry.wingsMaxContent / WingsDevice.width), 1)
    }

    var statsWingLeftV2: some View {
        let devices = wingsDevices
        return HStack(spacing: WingsDevice.spacing) {
            if devices.isEmpty {
                WingLabel(symbol: "battery.100percent", text: "No device found")
            }
            ForEach(devices.prefix(wingsDevicesFitting)) { WingsDevice(device: $0) }
        }
        // Widened, the batteries stay next to the notch.
        .frame(maxWidth: model.wings.isWide ? .infinity : nil, alignment: .trailing)
        .onAppear { stats.setVisible(true) }
        .onDisappear {
            stats.setVisible(model.isExpanded && !model.isPreview && model.currentFeature == .stats)
            if model.wings.isWide { model.wings.isWide = false }
        }
    }

    @ViewBuilder var statsWingRightV2: some View {
        let hidden = Array(wingsDevices.dropFirst(wingsDevicesFitting))
        if model.wings.isWide {
            HStack(spacing: WingsDevice.spacing) {
                ForEach(hidden) { WingsDevice(device: $0) }
                Divider().frame(height: 14)
                statsMemory
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .global) { phase in
                wingsWideHover(phase)
            }
        } else {
            HStack(spacing: 8) {
                statsMemory
                if !hidden.isEmpty {
                    WingButton(title: "+\(hidden.count)", symbol: "chevron.right.2", help: "Show every device") {
                        withAnimation(NotchController.animation) { model.wings.isWide = true }
                    }
                }
            }
        }
    }

    @ViewBuilder private var statsMemory: some View {
        if let memory = stats.snapshot.memory {
            HStack(spacing: 6) {
                WingText("Memory", dim: true)
                WingText(StatsFormat.bytes(Double(memory.used)), bold: true)
                WingText("· Swap", dim: true)
                WingText(StatsFormat.bytes(Double(memory.swapUsed)), bold: true)
            }
        }
    }

    /// Widened: when the pointer heads back towards the notch, the wings narrow again.
    private func wingsWideHover(_ phase: HoverPhase) {
        guard case .active(let location) = phase else { return }
        let distance = location.x - geometry.windowSize.width / 2
        let furthest = max(model.wings.furthest, distance)
        if furthest != model.wings.furthest { model.wings.furthest = furthest }
        if distance < furthest - WingsDevice.backOff {
            withAnimation(NotchController.animation) {
                model.wings.isWide = false
                model.wings.furthest = 0
            }
        }
    }

    // MARK: Reminders (spec PV-18)

    /// The task added last; its icon drops the tasks' list down.
    @ViewBuilder var remindersWingLeftV2: some View {
        let newest = reminders.open.max { ($0.created ?? .distantPast) < ($1.created ?? .distantPast) }
        HStack(spacing: 6) {
            WingsTaskIcon(state: $model.wings, dropHeight: wingsTaskDropHeight)
            if let newest {
                WingsMarquee(text: newest.title, bold: true)
            } else {
                WingText("Nothing open", bold: true)
            }
        }
    }

    private var wingsTaskDropHeight: CGFloat {
        let count = min(tasks.listed.count, IndicatorLayout.taskRows)
        return IndicatorLayout.labelHeight + CGFloat(max(count, 1)) * 22 + 6
    }

    /// The tasks' list under the wings, as under the notch's task counter (spec PV-18, R-12).
    @ViewBuilder var wingsDropDown: some View {
        if model.wings.dropHeight > 0 {
            let listed = tasks.listed
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "checklist")
                        .font(.notch(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                    WingText(listed.isEmpty ? "No open tasks" : "\(listed.count) open task\(listed.count == 1 ? "" : "s")", bold: true)
                    Spacer(minLength: 8)
                    WingButton(title: "Open", symbol: nil, help: "Open Reminders", action: openFully)
                }
                .padding(.horizontal, 12)
                .frame(height: IndicatorLayout.labelHeight - 4)
                ForEach(listed.prefix(IndicatorLayout.taskRows)) { task in
                    TaskDropDownRow(task: task) { tasks.complete(task) }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
            .frame(maxWidth: 420)
            .frame(height: model.wings.dropHeight, alignment: .top)
            .contentShape(Rectangle())
            .onHover { inside in
                model.wings.isOnDrop = inside
                if !inside { withAnimation(NotchController.animation) { model.wings.closeDrop() } }
            }
            .transition(.opacity)
        }
    }
}

/// A device's symbol and charge in the wings.
struct WingsDevice: View {
    let device: BatteryDevice

    /// Room one device takes, with the gap after it.
    static let width: CGFloat = 58
    static let spacing: CGFloat = 10
    /// How far back towards the notch the pointer goes before widened wings narrow.
    static let backOff: CGFloat = 60

    var body: some View {
        HStack(spacing: 4) {
            BatteryDeviceIcon(kind: device.kind, size: 12)
            WingText("\(device.level)%", bold: device.kind == .mac)
                .foregroundStyle(device.isLow ? .red : .white)
                .monospacedDigit()
        }
        .help(device.name)
    }
}

/// The task symbol in the wings: resting on it drops the tasks' list (spec PV-18).
struct WingsTaskIcon: View {
    @Binding var state: WingsState
    let dropHeight: CGFloat

    @State private var leave: Task<Void, Never>?

    var body: some View {
        WingSymbol("checklist")
            .padding(4)
            .contentShape(Rectangle())
            .onHover { inside in
                leave?.cancel()
                if inside {
                    withAnimation(NotchController.animation) { state.dropHeight = dropHeight }
                } else {
                    // Time to move down onto the list.
                    leave = Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        guard !Task.isCancelled, !state.isOnDrop else { return }
                        withAnimation(NotchController.animation) { state.closeDrop() }
                    }
                }
            }
            .onDisappear {
                leave?.cancel()
                if state.dropHeight > 0 { state.closeDrop() }
            }
    }
}
