import SwiftUI

/// Battery levels over the last week, per device (spec BT-4), kept on disk.
struct BatterySample: Codable, Equatable, Sendable {
    let date: Date
    let level: Int
}

@MainActor
final class BatteryHistory {
    private(set) var samples: [String: [BatterySample]] = [:]
    private let file: URL
    static let keep: TimeInterval = 7 * 86_400

    init(file: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.file = file ?? support.appendingPathComponent("Dynotch/battery-history.json")
        if let data = try? Data(contentsOf: self.file),
           let stored = try? JSONDecoder().decode([String: [BatterySample]].self, from: data) {
            samples = stored
        }
    }

    func record(_ devices: [BatteryDevice], at now: Date = Date()) {
        let limit = now.addingTimeInterval(-Self.keep)
        for device in devices {
            var list = (samples[device.id] ?? []).filter { $0.date >= limit }
            list.append(BatterySample(date: now, level: device.level))
            samples[device.id] = list
        }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(samples) { try? data.write(to: file, options: .atomic) }
    }

    /// Time left at the recent rate of discharge (the last day's falling samples); nil while
    /// charging or without enough data.
    nonisolated static func estimate(from samples: [BatterySample], now: Date = Date()) -> TimeInterval? {
        let recent = samples.filter { now.timeIntervalSince($0.date) <= 86_400 }
        guard let first = recent.first, let last = recent.last, last.date > first.date, first.level > last.level else { return nil }
        let perSecond = Double(first.level - last.level) / last.date.timeIntervalSince(first.date)
        guard perSecond > 0 else { return nil }
        return Double(last.level) / perSecond
    }

    nonisolated static func estimateText(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        if hours < 1 { return "under an hour left" }
        if hours < 36 { return "about \(Int(hours.rounded())) hours left" }
        return "about \(Int((hours / 24).rounded())) days left"
    }
}

/// The last day's levels as a small line, for the low-battery label (spec BT-6).
struct BatterySparkline: View {
    let samples: [BatterySample]

    var body: some View {
        GeometryReader { geometry in
            let recent = samples.filter { Date().timeIntervalSince($0.date) <= 86_400 }
            let shown = recent.count > 1 ? recent : Array(samples.suffix(2))
            let start = shown.first?.date ?? Date()
            let span = max((shown.last?.date ?? Date()).timeIntervalSince(start), 1)
            Path { path in
                for (index, sample) in shown.enumerated() {
                    let point = CGPoint(
                        x: geometry.size.width * sample.date.timeIntervalSince(start) / span,
                        y: geometry.size.height * (1 - CGFloat(sample.level) / 100)
                    )
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            .stroke(BatteryFeatureView.red, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
