import Foundation

// Replying through the web app: open the conversation in the background, check it is the right
// one and its message box is empty, write, send, and see the message arrive (spec GW-9, GW-10).
extension GoogleChatWebService {
    private static let openTimeout: Duration = .seconds(5)
    private static let confirmTimeout: Duration = .seconds(5)
    private static let step: Duration = .milliseconds(250)

    /// Sends a reply to the conversation a notification title names.
    /// - Throws: `Unavailable` when nothing was written (the caller may reply the old way),
    ///   `Failure` once the send button was pressed but the message did not show up.
    func reply(_ text: String, toTitle title: String) async throws -> String {
        guard isEnabled, state == .reading, let pid = Self.webAppPID(),
              let conversation = conversation(forTitle: title)
        else { throw Unavailable() }
        let target = conversation.key
        let hint = windowTokenHint

        if await read(pid)?.openID != target {
            guard await Task.detached(operation: { GoogleChatWebReader.open(conversation.id, pid: pid, windowToken: hint) }).value
            else { throw Unavailable() }
        }
        // Write only into the right conversation's empty message box.
        let isReady: (ChatWebSnapshot) -> Bool = { $0.openID == target && $0.composer.map(GoogleChatWebReader.isBlank) == true }
        guard let ready = await waitFor(pid, timeout: Self.openTimeout, isReady) else { throw Unavailable() }
        let before = Set(ready.messages.map(\.id))

        let written = await Task.detached { GoogleChatWebReader.write(text, pid: pid, windowToken: hint) }.value
        let pressed = written ? await Task.detached { GoogleChatWebReader.pressSend(pid: pid, windowToken: hint) }.value : false
        guard pressed else {
            // Leave the box as it was; nothing went out.
            _ = await Task.detached { GoogleChatWebReader.write("", pid: pid, windowToken: hint) }.value
            throw Unavailable()
        }
        DiagnosticsLog.write("google-chat-web", "reply: send pressed")

        let wanted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let arrived = await waitFor(pid, timeout: Self.confirmTimeout) { snapshot in
            snapshot.openID == target && snapshot.messages.contains { !before.contains($0.id) && $0.text.contains(wanted) }
        }
        refresh()
        guard arrived != nil else {
            DiagnosticsLog.write("google-chat-web", "reply: not confirmed")
            throw Failure(description: "Not sent? It didn't show up in Google Chat: check there.")
        }
        DiagnosticsLog.write("google-chat-web", "reply: confirmed")
        return "Sent"
    }

    func read(_ pid: pid_t) async -> ChatWebSnapshot? {
        let hint = windowTokenHint
        return await Task.detached { GoogleChatWebReader.snapshot(pid: pid, windowToken: hint)?.0 }.value
    }

    func waitFor(
        _ pid: pid_t, timeout: Duration, _ condition: @escaping (ChatWebSnapshot) -> Bool
    ) async -> ChatWebSnapshot? {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let snapshot = await read(pid), condition(snapshot) { return snapshot }
            try? await Task.sleep(for: Self.step)
        }
        return nil
    }
}
