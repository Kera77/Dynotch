import SwiftUI

/// A device's symbol: the first of its candidates this macOS knows.
struct BatteryDeviceIcon: View {
    let kind: BatteryDevice.Kind
    var size: CGFloat = 16
    var color: Color = .white

    @MainActor private static var resolved: [BatteryDevice.Kind: String] = [:]

    @MainActor static func symbol(for kind: BatteryDevice.Kind) -> String {
        if let known = resolved[kind] { return known }
        let name = kind.symbols.first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil } ?? "battery.50percent"
        resolved[kind] = name
        return name
    }

    var body: some View {
        Image(systemName: Self.symbol(for: kind))
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
    }
}

/// Battery levels in the notch (spec BT-1): one row per device, as in macOS's own list.
struct BatteryFeatureView: View {
    @ObservedObject var service: BatteryService
    let isActive: Bool

    static let green = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let red = Color(red: 1, green: 0.3, blue: 0.3)

    var body: some View {
        Group {
            if service.devices.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "battery.0percent").font(.system(size: 16))
                    Text(service.lastUpdated == nil ? "Reading batteries…" : "No device with a battery found")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        ForEach(Array(service.devices.enumerated()), id: \.element.id) { index, device in
                            if index > 0 {
                                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.leading, 44)
                            }
                            row(device)
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
        .padding(.top, 4)
        .onAppear { if isActive { service.refresh() } }
        .onChange(of: isActive) { _, active in
            if active { service.refresh() }
        }
    }

    @State private var expanded: String?

    private func row(_ device: BatteryDevice) -> some View {
        let color = device.isLow ? Self.red : Color.white
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                BatteryDeviceIcon(kind: device.kind, size: 14, color: Color.white.opacity(0.85))
                    .frame(width: 28)
                Text(device.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(device.level)%")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(color)
                BatteryGauge(level: device.level, isCharging: device.isCharging, isLow: device.isLow)
            }
            .frame(height: 30)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(Motion.quick) { expanded = expanded == device.id ? nil : device.id } }
            if expanded == device.id {
                BatteryChart(samples: service.history.samples[device.id] ?? [])
                    .padding(.leading, 38)
                    .padding(.bottom, 6)
            }
        }
    }
}

/// The last week of one device (spec BT-4): a line of its level, and the time left.
struct BatteryChart: View {
    let samples: [BatterySample]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if samples.count < 2 {
                Text("The chart fills in over the next hours.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.5))
            } else {
                GeometryReader { geometry in
                    let start = samples.first?.date ?? Date()
                    let span = max(Date().timeIntervalSince(start), 1)
                    Path { path in
                        for (index, sample) in samples.enumerated() {
                            let point = CGPoint(
                                x: sample.date.timeIntervalSince(start) / span * geometry.size.width,
                                y: (1 - CGFloat(sample.level) / 100) * geometry.size.height
                            )
                            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                    }
                    .stroke(Theme.green, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)))
                if let left = BatteryHistory.estimate(from: samples) {
                    Text(BatteryHistory.estimateText(left))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
        }
    }
}

/// A small battery outline filled to the level; a bolt while charging.
struct BatteryGauge: View {
    let level: Int
    let isCharging: Bool
    let isLow: Bool

    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isLow ? BatteryFeatureView.red : BatteryFeatureView.green)
                    .frame(width: max(2, 18 * CGFloat(level) / 100))
                    .padding(2)
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 22, height: 11)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.45))
                .frame(width: 2, height: 5)
        }
    }
}
