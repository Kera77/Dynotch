import SwiftUI

// MARK: - Wingmate Wings: Stats and Reminders, v0.76 (spec PV-31, PV-33)

extension NotchView {
    // MARK: Stats (spec PV-31)

    /// The Mac first, then the other devices.
    private var wingsDevices: [BatteryDevice] {
        battery.devices.filter { $0.kind == .mac } + battery.devices.filter { $0.kind != .mac }
    }

    /// Four devices next to the notch; the others open to the left from "+N".
    var statsWingLeftV2: some View {
        let devices = wingsDevices
        // Eight on a large display (spec PV-75).
        let shown = geometry.isRoomy ? 2 * WingsDevice.shown : WingsDevice.shown
        let first = Array(devices.prefix(shown))
        let others = Array(devices.dropFirst(shown))
        return HStack(spacing: WingsDevice.spacing) {
            if devices.isEmpty {
                WingLabel(symbol: "battery.100percent", text: "No device found")
            }
            if model.wings.isWide {
                ForEach(others) { WingsDevice(device: $0) }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if !others.isEmpty {
                Text("+\(others.count)")
                    .font(.notch(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.level(0.14)))
                    .contentShape(Rectangle())
                    .help("Show every device")
                    .onHover { inside in
                        if inside { withAnimation(NotchController.animation) { model.wings.isWide = true } }
                    }
            }
            ForEach(first) { WingsDevice(device: $0) }
        }
        .contentShape(Rectangle())
        .onHover { inside in
            if !inside, model.wings.isWide { withAnimation(NotchController.animation) { model.wings.isWide = false } }
        }
        .onAppear { stats.setVisible(true) }
        .onDisappear {
            stats.setVisible(model.isExpanded && !model.isPreview && model.currentFeature == .stats)
        }
    }

    @ViewBuilder var statsWingRightV2: some View {
        if let memory = stats.snapshot.memory {
            HStack(spacing: 6) {
                WingText("Memory", dim: true)
                WingText(StatsFormat.bytes(Double(memory.used)), bold: true)
                WingText("· Swap", dim: true)
                WingText(StatsFormat.bytes(Double(memory.swapUsed)), bold: true)
            }
        }
    }

    // MARK: Reminders (spec PV-33)

    /// Open reminders, the newest first, without the ones ticked off in the Wings.
    private var wingsTasks: [ReminderItem] {
        reminders.open
            .filter { !model.wingsLasting.done.contains($0.id) && !reminders.completing.contains($0.id) }
            .sorted { ($0.created ?? .distantPast) > ($1.created ?? .distantPast) }
    }

    /// Left: the newest; right: the next due, else the second newest.
    private var wingsTaskPair: (left: ReminderItem?, right: ReminderItem?) {
        let tasks = wingsTasks
        let left = tasks.first
        let rest = tasks.dropFirst()
        let due = rest.filter { $0.due != nil }.min { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
        return (left, due ?? rest.first)
    }

    @ViewBuilder var remindersWingLeftV2: some View {
        let left = wingsTaskPair.left
        ZStack(alignment: .trailing) {
            if let left {
                wingsTaskLine(left)
                    .id(left.id)
                    // The next one swims out of the notch.
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
                WingText("Nothing open", bold: true)
            }
        }
        .animation(NotchController.animation, value: left?.id)
    }

    @ViewBuilder var remindersWingRightV2: some View {
        let right = wingsTaskPair.right
        ZStack(alignment: .leading) {
            if let right {
                wingsTaskLine(right)
                    .id(right.id)
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(NotchController.animation, value: right?.id)
    }

    private func wingsTaskLine(_ item: ReminderItem) -> some View {
        WingsTaskLine(
            item: item,
            color: reminders.list(for: item)?.color.color ?? Theme.blue,
            due: WingFormat.due(of: item, now: Date()),
            isOverdue: item.isOverdue(at: Date()),
            isTicked: model.wingsLasting.ticked[item.id] != nil,
            tick: { tickWingsTask(item) }
        )
    }

    /// Ticked: a second click on the ring unticks it; left ticked for a few seconds, it is
    /// completed in Reminders and the next one shows (spec PV-44).
    private func tickWingsTask(_ item: ReminderItem) {
        if model.wingsLasting.ticked[item.id] != nil {
            withAnimation(Motion.quick) { model.wingsLasting.ticked[item.id] = nil }
            return
        }
        // A tick taken back and given again waits its own full time.
        let tick = UUID()
        withAnimation(Motion.quick) { model.wingsLasting.ticked[item.id] = tick }
        Task { [model, reminders] in
            try? await Task.sleep(for: WingsTaskLine.untickTime)
            guard model.wingsLasting.ticked[item.id] == tick else { return }
            reminders.complete(item)
            let openIDs = Set(reminders.open.map(\.id))
            withAnimation(NotchController.animation) {
                model.wingsLasting.ticked[item.id] = nil
                model.wingsLasting.done = model.wingsLasting.done.intersection(openIDs).union([item.id])
            }
        }
    }
}

/// A device's symbol and charge in the wings.
struct WingsDevice: View {
    let device: BatteryDevice

    /// How many stand next to the notch before "+N" (spec PV-31).
    static let shown = 4
    static let spacing: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            BatteryDeviceIcon(kind: device.kind, size: 12)
            WingText("\(device.level)%", bold: device.kind == .mac)
                .foregroundStyle(device.isLow ? .red : .white)
                .monospacedDigit()
        }
        .fixedSize()
        .help(device.name)
    }
}

/// A reminder in the wings: a ring that takes its list's colour on hover and ticks it off, the
/// title and when it is due; ticked, it is struck through until the ring is clicked again (spec PV-33, PV-44).
struct WingsTaskLine: View {
    let item: ReminderItem
    let color: Color
    let due: String?
    let isOverdue: Bool
    let isTicked: Bool
    let tick: () -> Void

    /// How long a tick can be taken back by clicking the ring again.
    static let untickTime: Duration = .seconds(4)

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: tick) {
                Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                    .font(.notch(size: 13, weight: .regular))
                    .foregroundStyle(isTicked || isHovered ? color : Color.white.level(0.6))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(isTicked ? "Keep it open" : "Done")
            .onHover { inside in withAnimation(Motion.hover) { isHovered = inside } }
            if isTicked {
                Text(item.title)
                    .font(.notch(size: 12, weight: .semibold))
                    .strikethrough()
                    .foregroundStyle(Color.white.level(0.5))
                    .lineLimit(1)
            } else {
                WingsMarquee(text: item.title, bold: true)
                if let due {
                    WingText(due, dim: !isOverdue).foregroundStyle(isOverdue ? .red : Color.white.level(0.6))
                }
            }
        }
    }
}

extension WingFormat {
    /// When a reminder is due: the time today, otherwise the day and the time (spec PV-33).
    static func due(of item: ReminderItem, now: Date) -> String? {
        guard let due = item.due else { return nil }
        let time = item.dueHasTime ? due.formatted(date: .omitted, time: .shortened) : nil
        if let day = day(of: due, now: now) {
            return [day, time].compactMap { $0 }.joined(separator: " ")
        }
        return time ?? "Today"
    }
}
