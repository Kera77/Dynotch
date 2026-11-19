import SwiftUI

/// A device that came or went, hanging under the notch (spec DV-1, DV-2, DV-4, DV-9, DV-10): its
/// icon, name, state and batteries, and its quick buttons (macOS's own one in blue).
struct DevicePeekView: View {
    let event: DeviceEvent
    let notchHeight: CGFloat
    let perform: (DeviceEvent.Action) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 12) {
                Image(systemName: event.symbol)
                    .font(.notch(size: 21, weight: .medium))
                    .foregroundStyle(event.isConnected ? Theme.green : Color.white.level(0.45))
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: AppleStyle.corner(12), style: .continuous).fill(Color.white.level(0.08)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.name)
                        .font(.notch(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    statusLine
                    if !event.levels.isEmpty {
                        // Each earbud and the case with its own icon (spec DV-8b, DV-9).
                        HStack(spacing: 10) {
                            ForEach(event.levels) { level in levelView(level) }
                        }
                    }
                }
                ForEach(Array(event.actions.enumerated()), id: \.offset) { _, action in actionButton(action) }
            }
            // Always centred under the notch (spec DV-11).
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .frame(maxHeight: .infinity)
        }
    }

    /// "Connected" with a tick, "Disconnected", or the device's own detail (drive size…).
    private var statusLine: some View {
        HStack(spacing: 4) {
            if event.detail == nil {
                Image(systemName: event.isConnected ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.notch(size: 10, weight: .semibold))
            }
            Text(event.detail ?? (event.isConnected ? "Connected" : "Disconnected"))
                .font(.notch(size: 11, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(event.detail == nil && event.isConnected ? Theme.green : Color.white.level(0.6))
    }

    private func levelView(_ level: DeviceLevel) -> some View {
        HStack(spacing: 3) {
            if let symbol = level.symbols.first(where: { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }) {
                Image(systemName: symbol).font(.notch(size: 11))
            } else {
                Text(level.title).font(.notch(size: 10, weight: .semibold))
            }
            Text("\(level.percent)%").font(.notch(size: 11, weight: .medium)).monospacedDigit().numericTransition()
        }
        .foregroundStyle(level.percent <= 20 ? BatteryFeatureView.red : Color.white.level(0.75))
        .help(level.title.isEmpty ? "Battery" : level.title)
    }

    @ViewBuilder
    private func actionButton(_ action: DeviceEvent.Action) -> some View {
        switch action {
        case .open: button("Open", action)
        case .eject: button("Eject", action)
        case .useForAudio: button("Use for audio", action)
        case .displaySettings: button("Displays…", action)
        case .bluetoothButton(let title, _): button(title, action, prominent: true)
        }
    }

    private func button(_ title: String, _ action: DeviceEvent.Action, prominent: Bool = false) -> some View {
        Button(title) { perform(action) }
            .buttonStyle(.notch)
            .font(.notch(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .frame(height: 26)
            .background(Capsule().fill(prominent ? Theme.blue : Color.white.level(0.15)))
    }
}
