import SwiftUI

/// Settings › Notifications › Google Chat: read the web app, how often, and what it sees (spec GW-14).
struct GoogleChatWebSettingsSection: View {
    @ObservedObject var chatWeb: GoogleChatWebService

    var body: some View {
        Section {
            Toggle("Read from the Google Chat web app", isOn: $chatWeb.isEnabled)
            if chatWeb.isEnabled {
                LabeledContent("Check every") {
                    HStack(spacing: 6) {
                        Text("\(chatWeb.interval) s").monospacedDigit()
                        Stepper("", value: $chatWeb.interval, in: GoogleChatWebService.intervalRange, step: 5).labelsHidden()
                    }
                }
                LabeledContent("Status") {
                    Text(status).foregroundStyle(chatWeb.state == .reading ? .green : .secondary)
                }
            }
        } header: {
            Text("Google Chat")
        } footer: {
            Text("Reads the Google Chat web app added to the Dock from Safari, through Accessibility only: "
                + "a chat read there leaves the notch, and replies go straight into it. Nothing is sent anywhere else, "
                + "and messages are kept in memory only. Without it, notifications and typing are used.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var status: String {
        switch chatWeb.state {
        case .off: "Off"
        case .noAccess: "Needs Accessibility access"
        case .notRunning: "The Google Chat web app isn't running"
        case .notRecognized: "Not readable: the page wasn't recognized"
        case .reading:
            "Reading · \(chatWeb.snapshot?.unreadTotal ?? 0) unread"
                + (chatWeb.snapshot?.hasHome == true
                    ? " · with message text"
                    : " · no message text: open the web app's Home and keep its window out of the Dock")
        }
    }
}
