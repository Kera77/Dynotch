import AppKit
import SwiftUI

/// Beside the closed notch: the speaker or sun on the left; on the right the level in white, as
/// the AI session stands in the wings: the percentage and a small ring filling clockwise
/// (spec H-1…H-3, H-3c).
struct HUDView: View {
    let display: HUDService.Display
    let notchWidth: CGFloat

    /// Wide enough for "100%" and the ring.
    static let sideWidth: CGFloat = 64
    /// The ring at the wings' size (spec H-3c).
    private static let ringScale: CGFloat = 0.75

    /// How far the ring has filled while the HUD opens or closes (spec H-3c).
    @Environment(\.hudReveal) private var reveal

    var body: some View {
        let side = Self.sideWidth(for: display)
        HStack(spacing: 0) {
            // One fixed symbol per kind: no animated swaps while the level changes.
            Image(systemName: symbol)
                .font(.notch(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: side)
            Color.clear.frame(width: notchWidth)
            if case .announcement(_, let text) = display.kind {
                // A few words instead of the level (spec HA-1).
                Text(text)
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: side)
            } else {
                levelSide.frame(width: side)
            }
        }
    }

    private var levelSide: some View {
        HStack(spacing: 5) {
            Text("\(LevelRing.label(for: level))%")
                .font(.notch(size: 12, weight: .semibold))
                .monospacedDigit()
                .numericTransition()
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
            LevelRing(fraction: level * reveal, color: .white, label: "")
                .scaleEffect(Self.ringScale)
                .frame(width: LevelRing.size * Self.ringScale, height: LevelRing.size * Self.ringScale)
        }
        .animation(Motion.quick, value: level)
    }

    /// Both sides as wide as the announcement's words need, at least the level's width (spec HA-1).
    static func sideWidth(for display: HUDService.Display) -> CGFloat {
        guard case .announcement(_, let text) = display.kind else { return sideWidth }
        let width = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold)]).width
        return max(sideWidth, ceil(width) + 20)
    }

    private var level: Double {
        display.muted ? 0 : display.level
    }

    private var symbol: String {
        switch display.kind {
        case .volume: display.muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        case .brightness: "sun.max.fill"
        case .announcement(let symbol, _): symbol
        }
    }
}

private struct HUDRevealKey: EnvironmentKey {
    static let defaultValue: Double = 1
}

extension EnvironmentValues {
    /// 0…1: the HUD ring's share of its level while the HUD opens or closes (spec H-3c).
    var hudReveal: Double {
        get { self[HUDRevealKey.self] }
        set { self[HUDRevealKey.self] = newValue }
    }
}

/// Fills the HUD's ring as it comes and empties it as it goes (spec H-3c): an animatable step
/// between 0 and 1 that the ring reads from the environment.
struct HUDRevealModifier: ViewModifier, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.environment(\.hudReveal, progress)
    }
}

extension AnyTransition {
    /// Fades the HUD in while its ring fills, out while it empties (spec H-3c).
    static func hudReveal(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .opacity.combined(with: .modifier(active: HUDRevealModifier(progress: 0), identity: HUDRevealModifier(progress: 1)))
    }
}
