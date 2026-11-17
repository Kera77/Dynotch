import SwiftUI

/// Tablet button in the panel's top row, beside "focus follows mouse": its menu connects an iPad as a display,
/// like the "+" menu of macOS's Displays settings (spec TB-1).
struct TabletMenu: View {
    @ObservedObject var service: TabletDisplayService

    var body: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: "ipad.landscape")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: TrailingControlsMetrics.buttonWidth, height: 22)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .offset(x: -3, y: -2)
                }
                .foregroundStyle(service.connected != nil ? ClaudeUsageView.blue : Color.white.opacity(0.45))
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("iPad as a display")
        .onAppear { service.refresh() }
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
                Picker("Use as", selection: Binding(get: { service.isMirrored }, set: { service.setMirrored($0) })) {
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
        Button("Display Settings…") { service.openDisplaySettings() }
    }
}
