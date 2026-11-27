import SwiftUI

/// The hover controls of the Tools indicator (spec TM-19, TM-20): under the notch a row like a
/// small notice, beside the notch the buttons right of the time.
struct ToolsControlsLabel: View {
    let glance: ToolsGlance
    let now: Date
    let open: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            if let clock = glance.clock {
                Image(systemName: clock.symbol)
                    .font(.notch(size: 11, weight: .semibold))
                    .foregroundStyle(ToolsSlot.color(clock.tint))
                Text(clock.title.isEmpty ? clock.tab.title : clock.title)
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(ClockText.text(clock.seconds(at: now), tenths: false) + (clock.isPaused ? " · paused" : ""))
                    .font(.notch(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.level(0.6))
                    .lineLimit(1)
            } else {
                Text(glance.micMuted ? "Microphone muted" : "Keeping awake")
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            ToolsControlsRow(glance: glance, open: open)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(height: IndicatorLayout.labelHeight - 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The buttons, then the arrow that opens the Tools on the shown tab (spec TM-19, TM-20).
struct ToolsControlsRow: View {
    let glance: ToolsGlance
    let open: () -> Void

    var body: some View {
        HStack(spacing: IndicatorLayout.toolsControlSpacing) {
            ForEach(glance.controls) { control in
                button(control.symbol, help: control.help) {
                    ToolsService.shared.perform(control, on: glance.clock)
                }
            }
            button("arrow.up.right", help: "Open Tools", action: open)
        }
        .padding(.leading, 4)
    }

    private func button(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.notch(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: IndicatorLayout.toolsControlSize, height: IndicatorLayout.toolsControlSize)
                .background(Circle().fill(Color.white.level(0.16)))
                .contentShape(Circle())
        }
        .buttonStyle(.notch)
        .help(help)
        .accessibilityLabel(help)
    }
}

extension NotchIndicatorView {
    /// Beside the notch the controls widen out of the time.
    @ViewBuilder
    func toolsCapsule(_ glance: ToolsGlance, now: Date) -> some View {
        if glance.unfolded {
            HStack(spacing: 0) {
                ToolsSlot(glance: glance, now: now)
                ToolsControlsRow(glance: glance, open: { openTools(glance.tab) })
            }
        } else {
            ToolsSlot(glance: glance, now: now)
        }
    }

    /// Under the notch the controls drop down; widened beside it, nothing does.
    @ViewBuilder
    func toolsLabel(_ glance: ToolsGlance, now: Date) -> some View {
        if !glance.unfolded {
            ToolsControlsLabel(glance: glance, now: now, open: { openTools(glance.tab) })
        }
    }
}
