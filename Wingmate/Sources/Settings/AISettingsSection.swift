import SwiftUI

/// Settings › General › AI: the default service and model (spec AI-9).
struct AISettingsSection: View {
    @Bindable var chat: ClaudeChatService

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
            Picker("ChatGPT answers", selection: Binding(get: { chat.chatGPTMode }, set: { chat.chatGPTMode = $0 })) {
                ForEach(ChatGPTMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            LabeledContent("ChatGPT account") {
                Button("Sign in to ChatGPT…", action: chat.signInToChatGPT)
                    .disabled(CodexCLI.locate() == nil)
            }
        } header: {
            Text("AI")
        } footer: {
            Text("Claude runs through Claude Code, ChatGPT through Codex in the ChatGPT app, each with the account this Mac is "
                + "signed in with. Codex answers in the notch (sign in once with the button, or open Codex in the ChatGPT app); "
                + "with a free account without Codex choose ChatGPT, which opens chatgpt.com. ⌃⌥A asks from anywhere.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
