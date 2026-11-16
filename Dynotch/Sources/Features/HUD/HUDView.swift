import SwiftUI

/// Beside the closed notch: the speaker or sun on the left, the level as a white ring filling
/// clockwise on the right (spec H-1…H-3).
struct HUDView: View {
    let display: HUDService.Display
    let notchWidth: CGFloat

    static let sideWidth: CGFloat = 40

    var body: some View {
        HStack(spacing: 0) {
            // One fixed symbol per kind: no animated swaps while the level changes.
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Self.sideWidth)
            Color.clear.frame(width: notchWidth)
            LevelRing(fraction: level, color: .white, label: LevelRing.label(for: level))
                .frame(width: Self.sideWidth)
        }
    }

    private var level: Double {
        display.muted ? 0 : display.level
    }

    private var symbol: String {
        switch display.kind {
        case .volume: display.muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        case .brightness: "sun.max.fill"
        }
    }
}
