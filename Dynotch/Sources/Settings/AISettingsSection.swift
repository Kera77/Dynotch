import SwiftUI

/// Settings › General › AI: the default service and model (spec AI-9).
struct AISettingsSection: View {
    @ObservedObject var chat: ClaudeChatService

    var body: some View {
        Section {
            Picker("Default service", selection: $chat.provider) {
                ForEach(AIProvider.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            ForEach(AIProvider.allCases, id: \.self) { provider in
                Picker("\(provider.title) model", selection: Binding(
                    get: { chat.model(for: provider) ?? "" },
                    set: { chat.setDefaultModel($0.isEmpty ? nil : $0, for: provider) }
                )) {
                    Text("Default").tag("")
                    ForEach(provider.models()) { Text($0.title).tag($0.id) }
                }
            }
        } header: {
            Text("AI")
        } footer: {
            Text("Claude runs through Claude Code, ChatGPT through Codex in the ChatGPT app, each with the account this Mac is "
                + "signed in with (a subscription or a free account). ⌃⌥A asks a quick question from anywhere; change it under Modules.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
