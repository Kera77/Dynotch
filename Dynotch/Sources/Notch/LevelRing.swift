import SwiftUI

/// A round level indicator with the value in the middle (spec H-3, CL-6): the ring fills
/// clockwise from the top. Sized and stroked to stay crisp on non-Retina displays too.
struct LevelRing: View {
    /// 0…1
    let fraction: Double
    let color: Color
    /// Shown in the middle, e.g. "62".
    let label: String

    static let size: CGFloat = 22
    private static let lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: Self.lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(Self.lineWidth / 2)
        .frame(width: Self.size, height: Self.size)
        // Rendered in one pass at the display's scale, so the thin strokes stay sharp.
        .drawingGroup()
    }

    static func label(for fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))"
    }
}
