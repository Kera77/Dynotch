import SwiftUI

enum StatsFormat {
    static func bytes(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(max(value, 0)), countStyle: .memory)
    }

    static func rate(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(max(value, 0)), countStyle: .decimal) + "/s"
    }

    /// Short, for beside the notch: "1.2M", "830K".
    nonisolated static func shortRate(_ value: Double) -> String {
        switch value {
        case ..<1_000: "0K"
        case ..<1_000_000: "\(Int(value / 1_000))K"
        case ..<10_000_000: String(format: "%.1fM", value / 1_000_000)
        default: "\(Int(value / 1_000_000))M"
        }
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    static func minutes(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

/// A small line chart of the last readings.
struct StatsSparkline: View {
    let values: [Double]
    /// nil: scaled to the largest value.
    var top: Double?
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let peak = max(top ?? (values.max() ?? 1), 0.000_001)
            let step = proxy.size.width / CGFloat(max(StatsService.historyLength - 1, 1))
            let start = proxy.size.width - CGFloat(max(values.count - 1, 0)) * step
            Path { path in
                for (index, value) in values.enumerated() {
                    let point = CGPoint(
                        x: start + CGFloat(index) * step,
                        y: proxy.size.height * (1 - CGFloat(min(value / peak, 1)))
                    )
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
    }
}

/// A bar filled to a share, e.g. memory or disk use.
struct StatsBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(color).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 5)
    }
}

/// One tile of the module: a title, a large value and details.
struct StatsCard<Content: View>: View {
    let title: String
    let symbol: String
    let value: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .semibold))
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .foregroundStyle(Color.white.opacity(0.6))
            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).fill(Theme.fill))
    }
}

/// Small grey lines under a card's value.
struct StatsDetail: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .monospacedDigit()
            .foregroundStyle(Color.white.opacity(0.5))
            .lineLimit(1)
    }
}

/// The value beside the closed notch: CPU or network speed, or a warning (spec SY-7, SY-8).
struct StatsSlot: View {
    @ObservedObject var service: StatsService
    @ObservedObject var indicator: StatsIndicator

    var body: some View {
        HStack(spacing: 3) {
            if !indicator.warnings.isEmpty {
                Circle().fill(Theme.red).frame(width: 6, height: 6)
            }
            switch indicator.mode {
            case .cpu:
                Text(StatsFormat.percent(service.snapshot.cpu)).foregroundStyle(cpuColor)
            case .network:
                Text("↓" + StatsFormat.shortRate(service.snapshot.download)).foregroundStyle(.white)
            case .off:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.red)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .frame(width: IndicatorLayout.statsSlotWidth, height: IndicatorLayout.capsuleHeight)
    }

    private var cpuColor: Color {
        service.snapshot.cpu > 0.85 ? Theme.red : service.snapshot.cpu > 0.6 ? .orange : .white
    }
}
