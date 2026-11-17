import SwiftUI

/// Tablet button at the left of the panel's top row: its menu connects an iPad as a display,
/// like the "+" menu of macOS's Displays settings (spec TB-1).
struct TabletMenu: View {
    @ObservedObject var service: TabletDisplayService

    /// Width in the top row, with the background's padding.
    static let width: CGFloat = 46
    /// Gap to the feature icons.
    static let spacing: CGFloat = 6

    var body: some View {
        Menu {
            menuContent
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "ipad.landscape")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundStyle(service.connected != nil ? ClaudeUsageView.blue : Color.white.opacity(0.7))
            .frame(width: Self.width - 6, height: 22)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(3)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.1)))
        .help("iPad as a display")
        .onAppear(perform: service.refresh)
    }

    @ViewBuilder private var menuContent: some View {
        Section("Mirror or extend to") {
            if service.tablets.isEmpty {
                Text("No iPad nearby")
            }
            ForEach(service.tablets) { tablet in
                Toggle(tablet.name, isOn: Binding(
                    get: { tablet.isConnected },
                    set: { $0 ? service.connect(tablet) : service.disconnect(tablet) }
                ))
                .disabled(service.pending != nil)
            }
        }
        if let tablet = service.connected {
            Section(tablet.name) {
                Picker("Use as", selection: Binding(get: { service.isMirrored }, set: service.setMirrored)) {
                    Text("Extended display").tag(false)
                    Text("Mirror of the main display").tag(true)
                }
                .pickerStyle(.inline)
                Button("Disconnect") { service.disconnect(tablet) }
            }
        } else if !service.tablets.isEmpty {
            Section("Mirror") {
                ForEach(service.tablets) { tablet in
                    Button("Mirror to \(tablet.name)") { service.connect(tablet, mirrored: true) }
                        .disabled(service.pending != nil)
                }
            }
        }
        if let failure = service.failure {
            Text(failure)
        }
        Divider()
        Button("Display Settings…", action: service.openDisplaySettings)
    }
}
