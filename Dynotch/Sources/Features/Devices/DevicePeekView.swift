import SwiftUI

/// A device that came or went, hanging under the notch (spec DV-1, DV-2, DV-4): its icon, name
/// and battery, a green tick or a grey crossed circle, and its quick buttons.
struct DevicePeekView: View {
    let event: DeviceEvent
    let notchHeight: CGFloat
    let perform: (DeviceEvent.Action) -> Void

    private static let green = Color(red: 0.2, green: 0.84, blue: 0.4)

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)
            HStack(spacing: 12) {
                Image(systemName: event.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(event.isConnected ? Self.green : Color.white.opacity(0.45))
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white.opacity(0.08)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(event.detail ?? (event.isConnected ? "Connected" : "Disconnected"))
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                ForEach(Array(event.actions.enumerated()), id: \.offset) { _, action in
                    if case .open = action { button("Open", action) }
                    if case .eject = action { button("Eject", action) }
                    if case .useForAudio = action { button("Use for audio", action) }
                    if case .displaySettings = action { button("Displays…", action) }
                }
                Image(systemName: event.isConnected ? "checkmark.circle" : "xmark.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(event.isConnected ? Self.green : Color.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
        }
    }

    private func button(_ title: String, _ action: DeviceEvent.Action) -> some View {
        Button(title) { perform(action) }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(Capsule().fill(Color.white.opacity(0.15)))
    }
}
