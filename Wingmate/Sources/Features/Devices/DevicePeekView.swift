import SwiftUI

/// A device that came or went, hanging under the notch in one row like "Claude finished" (spec
/// DV-1, DV-2, DV-4, DV-9, DV-10, DV-15): its icon, name, state and batteries, and its quick
/// buttons (macOS's own one in blue).
struct DevicePeekView: View {
    let event: DeviceEvent
    let notchHeight: CGFloat
    let perform: (DeviceEvent.Action) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 7) {
                Image(systemName: event.symbol)
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(event.isConnected ? Theme.green : Color.white.level(0.45))
                    .frame(width: 16)
                Text(event.name)
                    .font(.notch(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                statusLine.layoutPriority(1)
                // Each earbud and the case with its own icon (spec DV-8b, DV-9).
                ForEach(event.levels) { level in levelView(level).layoutPriority(1) }
                Spacer(minLength: 8)
                ForEach(Array(event.actions.enumerated()), id: \.offset) { _, action in
                    actionButton(action).layoutPriority(1)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: IndicatorLayout.labelHeight - 4)
            .frame(maxHeight: .infinity)
        }
    }

    /// What the row needs side to side: icon, name, state, batteries and buttons (spec E-31).
    static func contentWidth(_ event: DeviceEvent) -> CGFloat {
        let state = event.detail ?? (event.isConnected ? "Connected" : "Disconnected")
        let status = (event.detail == nil ? 14 : 0) + PeekText.width(state, size: 11, weight: .medium)
        var width = 12 + 16 + 7 + PeekText.width(event.name, size: 12, weight: .semibold) + 7 + status
        width += CGFloat(event.levels.count) * (7 + 14 + 3 + PeekText.width("100%", size: 11, weight: .medium))
        width += 8
        for action in event.actions { width += 7 + 18 + PeekText.width(title(of: action), size: 10.5, weight: .semibold) }
        return width + 12
    }

    private static func title(of action: DeviceEvent.Action) -> String {
        switch action {
        case .open: "Open"
        case .eject: "Eject"
        case .useForAudio: "Use for audio"
        case .displaySettings: "Displays…"
        case .bluetoothButton(let title, _): title
        }
    }

    /// "Connected" with a tick, "Disconnected", or the device's own detail (drive size…).
    var statusLine: some View {
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

    func levelView(_ level: DeviceLevel) -> some View {
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
    func actionButton(_ action: DeviceEvent.Action) -> some View {
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
            .font(.notch(size: 10.5, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .frame(height: 20)
            .background(Capsule().fill(prominent ? Theme.blue : Color.white.level(0.15)))
    }
}
