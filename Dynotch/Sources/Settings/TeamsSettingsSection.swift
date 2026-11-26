import SwiftUI

/// Settings › Chats › Teams (spec MT-3, MT-7, MT-8).
struct TeamsSettingsSection: View {
    @Bindable var teams: TeamsService

    var body: some View {
        Section {
            Toggle("Read the web Teams", isOn: $teams.isEnabled)
            if teams.isEnabled {
                LabeledContent("Status") {
                    Text(status).foregroundStyle(teams.state == .reading ? .green : .secondary)
                }
                LabeledContent("Mute shortcut") {
                    ShortcutRecorder(shortcut: teams.muteShortcut) { teams.muteShortcut = $0 }
                }
                Toggle("Warn when I talk while muted", isOn: $teams.warnsWhenMuted)
            }
        } header: {
            Text("Teams")
        } footer: {
            Text("Reads Teams open in a browser window of its own (Teams must be that window's front tab), through "
                + "Accessibility only: chats, replies and the meeting's controls. Nothing is sent anywhere else. The "
                + "warning checks the microphone's level only while Teams is muted; nothing is recorded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var status: String {
        switch teams.state {
        case .off: "Off"
        case .noAccess: "Needs Accessibility access"
        case .notFound: "No browser window shows Teams"
        case .reading:
            "Reading · \(teams.snapshot?.unread.count ?? 0) unread" + (teams.meeting != nil ? " · in a meeting" : "")
        }
    }
}
