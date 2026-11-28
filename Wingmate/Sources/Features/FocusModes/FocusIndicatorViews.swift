import SwiftUI

extension IndicatorLayout {
    /// The active Focus's icon (spec FC-4).
    static let focusSlotWidth: CGFloat = 26
}

/// The active Focus's icon beside the closed notch; a click turns the Focus off (spec FC-4).
struct FocusSlot: View {
    let active: FocusModeService.Active

    var body: some View {
        Button { FocusModeService.shared.turnOff() } label: {
            Image(systemName: active.mode.symbol)
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(active.mode.color)
                .frame(width: IndicatorLayout.focusSlotWidth, height: IndicatorLayout.capsuleHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(FocusModeService.shared.isSwitching ? 0.5 : 1)
        .help("Turn \(active.mode.name) off")
        .accessibilityLabel("Focus: \(active.mode.name). Click to turn it off")
    }
}

/// Under the row on hover: the Focus's name, the time left and Turn off (spec FC-4).
struct FocusLabel: View {
    let active: FocusModeService.Active
    let now: Date

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: active.mode.symbol)
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(active.mode.color)
            Text(active.mode.name)
                .font(.notch(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if let left = FocusModeService.remainingText(until: active.until, now: now) {
                Text(left)
                    .font(.notch(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.level(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button("Turn off") { FocusModeService.shared.turnOff() }
                .buttonStyle(.notch)
                .font(.notch(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .disabled(FocusModeService.shared.isSwitching)
                .help("Turn the Focus off")
        }
        .padding(.horizontal, 12)
        .frame(height: IndicatorLayout.labelHeight - 4)
    }
}
