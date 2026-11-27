import SwiftUI

/// Right of the closed notch (spec TM-3, QT-5): the countdown's icon, its time in white with a
/// small ring of what is left (as H-3c), "+N", then the muted microphone and Keep Awake.
struct ToolsSlot: View {
    let glance: ToolsGlance
    let now: Date

    var body: some View {
        HStack(spacing: 4) {
            if let clock = glance.clock {
                Image(systemName: clock.symbol)
                    .font(.notch(size: 11, weight: .semibold))
                    .foregroundStyle(color(clock.tint))
                    .frame(width: 13)
                Text(ClockText.text(clock.seconds(at: now), tenths: false))
                    .font(.notch(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(clock.isPaused ? 0.55 : 1))
                    .lineLimit(1)
                    .fixedSize()
                if glance.more > 0 {
                    Text("+\(glance.more)")
                        .font(.notch(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            if glance.micMuted {
                Image(systemName: "mic.slash.fill")
                    .font(.notch(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.red)
                    .frame(width: 12)
            }
            if glance.awake {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.notch(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 12)
            }
        }
        .frame(width: IndicatorLayout.toolsWidth(glance), height: IndicatorLayout.capsuleHeight, alignment: .leading)
    }

    func color(_ tint: ToolsGlance.Tint) -> Color { Self.color(tint) }

    static func color(_ tint: ToolsGlance.Tint) -> Color {
        switch tint {
        case .white: .white
        case .red: Theme.red
        case .green: Theme.green
        }
    }
}
