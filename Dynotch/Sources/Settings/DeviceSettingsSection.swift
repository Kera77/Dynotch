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
