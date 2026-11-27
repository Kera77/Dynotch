import SwiftUI

/// A round level indicator with the value in the middle (spec H-3, CL-6): the ring fills
/// clockwise from the top. Sized and stroked to stay crisp on non-Retina displays too.
struct LevelRing: View {
    /// 0…1
    let fraction: Double
    let color: Color
    /// Shown in the middle, e.g. "62".
    let label: String

    /// Even size and a 3-point line: the ring keeps its shape on non-Retina displays, where every
    /// point is a single pixel.
    /// Large enough that "100" stays clear of the ring (spec H-3).
    static let size: CGFloat = 28
    private static let lineWidth: CGFloat = 3
    /// The ring's inside less a margin on each side.
    static let textWidth: CGFloat = size - 2 * lineWidth - 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.level(0.22), lineWidth: Self.lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.notch(size: label.count > 2 ? 8 : 9.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                // A gap inside the ring, so the digits never touch it.
                .frame(width: Self.textWidth)
        }
        .padding(Self.lineWidth / 2)
        .frame(width: Self.size, height: Self.size)
    }

    static func label(for fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))"
    }
}
