import SwiftUI

/// Settings › General › Connected devices (spec DV-7).
struct DeviceSettingsSection: View {
    @ObservedObject var devices: DeviceWatcher

    var body: some View {
        Section {
            Toggle("Show devices that connect", isOn: $devices.isOn)
            Toggle("Also when they disconnect", isOn: $devices.showsDisconnects)
                .disabled(!devices.isOn)
            ForEach(DeviceEvent.Category.allCases, id: \.self) { category in
                Toggle(category.title, isOn: Binding(get: { devices.shows(category) }, set: { devices.setShows(category, enabled: $0) }))
                    .disabled(!devices.isOn)
                    .padding(.leading, 12)
            }
        } header: {
            Text("Connected devices")
        } footer: {
            Text("A notice under the notch with the device's battery; drives and disk images get Eject. Nothing shows for "
                + "30 seconds after waking, and a device going and coming within seconds shows once.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Settings › Notifications › Beeper (spec UM-7, BP-1b).
struct BeeperSettingsRows: View {
    @ObservedObject var beeper: BeeperService

    var body: some View {
        Toggle("Keep unread Beeper chats in the notch", isOn: $beeper.keepsUnread)
        Toggle("Show the chat list in the Beeper tab", isOn: $beeper.showsChatList)
    }
}

/// Settings › Notifications › Low battery: each device's warning level (spec BT-7).
struct LowBatterySettingsSection: View {
    @ObservedObject var battery: BatteryService

    /// Connected devices first, then the ones seen before, by name.
    private var rows: [BatteryDevice] {
        let connected = battery.devices
        let away = battery.known.filter { id, _ in !battery.devices.contains { $0.id == id } }
            .map { id, name in BatteryDevice(id: id, name: name, kind: Self.kind(id: id, name: name), level: 0) }
        return connected.sorted { $0.name < $1.name } + away.sorted { $0.name < $1.name }
    }

    var body: some View {
        Section {
            if rows.isEmpty {
                Text("Devices appear here once their battery has been read.")
                    .foregroundStyle(.secondary)
            }
            ForEach(rows, id: \.id) { row in
                Picker(selection: Binding(get: { battery.threshold(for: row.id) }, set: { battery.setThreshold($0, for: row.id) })) {
                    ForEach(BatteryRules.thresholdChoices, id: \.self) { value in
                        Text(value == 0 ? "Off" : "\(value)%").tag(value)
                    }
                } label: {
                    Label { Text(row.name).lineLimit(1) } icon: { BatteryDeviceIcon(kind: row.kind, size: 13, color: .primary) }
                }
            }
        } header: {
            Text("Low battery")
        } footer: {
            Text("Beside the notch: the device's icon and a red ring with its level, once it is at or under this level and not "
                + "charging. Closed with the X, it comes back after the device was charged 10 points above it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private static func kind(id: String, name: String) -> BatteryDevice.Kind {
        if id == "mac" { return .mac }
        return id.hasPrefix("bt-case:") ? .earbudsCase : .detect(name)
    }
}
