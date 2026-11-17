import AppKit
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
                .foregroundStyle(service.connected != nil ? ClaudeUsageView.blue : Color.white.opacity(0.45))
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("iPad as a display")
        .accessibilityLabel("iPad as a display")
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

/// The menus Dynotch has open (the tablet menu, list pickers…): when the notch closes under
/// them they close too, instead of staying on screen until the next click (spec TB-5).
@MainActor
enum OpenMenus {
    private static var menus: [NSMenu] = []
    private static var observers: [NSObjectProtocol] = []

    static func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { note in
                // Delivered on the main queue, where the menu lives.
                nonisolated(unsafe) let menu = note.object as? NSMenu
                MainActor.assumeIsolated { if let menu { menus.append(menu) } }
            },
            center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { note in
                nonisolated(unsafe) let menu = note.object as? NSMenu
                MainActor.assumeIsolated { menus.removeAll { $0 === menu } }
            }
        ]
    }

    static func closeAll() {
        let open = menus
        menus = []
        open.forEach { $0.cancelTracking() }
    }
}
