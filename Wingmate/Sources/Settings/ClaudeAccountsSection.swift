import SwiftUI

/// Settings › General › AI usage › Accounts: Claude Code's login and the accounts added with a
/// claude.ai sign-in (spec CL-8).
struct ClaudeAccountsSection: View {
    var usage: ClaudeUsageService

    var body: some View {
        Section {
            ForEach(usage.accounts) { account in
                AccountRow(usage: usage, account: account)
            }
            HStack {
                Button(usage.isSigningIn ? "Signing in…" : "Add account…") { usage.signIn() }
                    .disabled(usage.isSigningIn)
                if let message = usage.signInMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        } header: {
            Text("AI usage accounts")
        } footer: {
            Text("Add the account of the Claude desktop app (or any other) to see its usage too. It signs in in "
                + "your browser; Wingmate keeps and renews that sign-in in its own keychain item and never touches "
                + "Claude Code's or the desktop app's login. With several accounts the AI Usage view shows the one "
                + "in use (Auto) or the one you pick.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AccountRow: View {
    var usage: ClaudeUsageService
    let account: ClaudeAccount
    @State private var name = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: account.isClaudeCode ? "terminal" : "person.crop.circle")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            TextField("Name", text: $name)
                .textFieldStyle(.plain)
                .onSubmit { usage.rename(account.id, to: name) }
                .onChange(of: name) { _, value in
                    if !value.trimmingCharacters(in: .whitespaces).isEmpty { usage.rename(account.id, to: value) }
                }
            Spacer()
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !account.isClaudeCode {
                if usage.usage[account.id]?.state == .signedOut {
                    Button("Sign in again") { usage.signIn(replacing: account.id) }
                        .disabled(usage.isSigningIn)
                }
                Button("Remove", role: .destructive) { usage.remove(account.id) }
            }
        }
        .onAppear { name = account.name }
    }

    private var status: String {
        if usage.isConsuming(account.id) { return "In use" }
        switch usage.usage[account.id]?.state {
        case .loaded: return account.isClaudeCode ? "Claude Code login" : "Signed in"
        case .signedOut: return "Signed out"
        case .noCredentials: return "No Claude Code login"
        case .failed: return "Couldn't load"
        default: return ""
        }
    }
}
