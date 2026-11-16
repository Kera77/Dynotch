import SwiftUI

/// Beside the closed notch: the speaker or sun on the left, the level as a white ring filling
/// clockwise on the right (spec H-1…H-3).
struct HUDView: View {
    let display: HUDService.Display
    let notchWidth: CGFloat

    static let sideWidth: CGFloat = 40
    private static let ringSize: CGFloat = 17

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Self.sideWidth)
            Color.clear.frame(width: notchWidth)
            ZStack {
                Circle().stroke(Color.white.opacity(0.22), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: display.muted ? 0 : min(max(display.level, 0), 1))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.12), value: display.level)
            }
            .frame(width: Self.ringSize, height: Self.ringSize)
            .frame(width: Self.sideWidth)
        }
    }

    private var symbol: String {
        switch display.kind {
        case .volume: HUDLogic.volumeSymbol(level: display.level, muted: display.muted)
        case .brightness: display.level < 0.3 ? "sun.min.fill" : "sun.max.fill"
        }
    }
}
