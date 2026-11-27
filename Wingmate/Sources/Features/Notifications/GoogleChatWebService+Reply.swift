import Foundation

// Replying through the web app: open the conversation in the background, check it is the right
// one and its message box is empty, write, send, and see the message arrive (spec GW-9, GW-10).
extension GoogleChatWebService {
    private static let openTimeout: Duration = .seconds(8)
    private static let confirmTimeout: Duration = .seconds(5)
    private static let step: Duration = .milliseconds(100)

    /// Sends a reply to the conversation a notification title names. Returns once send was
    /// pressed; that it arrived is checked afterwards, then the web app goes back to Home
    /// (spec GW-30, GW-31).
    /// - Throws: `Unavailable` when nothing was written (the caller may reply the old way).
    func reply(_ text: String, toTitle title: String) async throws -> String {
        guard isEnabled, state == .reading, let pid = Self.webAppPID() else { throw Unavailable() }
        // A new reply: the previous one's check would see the wrong conversation.
        replyConfirmation?.cancel()
        replyConfirmation = nil
        let started = ContinuousClock.now
        // Not in the last background read: read the page again before giving up (spec GW-29).
        var found = conversation(forTitle: title)
        var fresh: ChatWebSnapshot?
        if found == nil {
            fresh = await read(pid)
            found = fresh.flatMap { Self.match(title, in: $0.conversations) }
        }
        guard let conversation = found else {
            DiagnosticsLog.write("google-chat-web", "reply: conversation not found")
            throw Unavailable()
        }
        let target = conversation.key
        let hint = windowTokenHint

        // Write only into the right conversation's empty message box.
        let isReady: (ChatWebSnapshot) -> Bool = { $0.openID == target && $0.composer.map(GoogleChatWebReader.isBlank) == true }
        // One read tells whether it is open and ready already.
        var current = fresh
        if current == nil { current = await read(pid) }
        var ready = current.flatMap { isReady($0) ? $0 : nil }
        if ready == nil {
            if current?.openID != target {
                guard await Task.detached(operation: { GoogleChatWebReader.open(conversation.id, pid: pid, windowToken: hint) }).value
                else { throw Unavailable() }
            }
            ready = await waitFor(pid, timeout: Self.openTimeout, isReady)
        }
        guard let ready else {
            DiagnosticsLog.write("google-chat-web", "reply: conversation or message box not ready")
            throw Unavailable()
        }
        let before = Set(ready.messages.map(\.id))
        let opened = ContinuousClock.now

        // Leaves the box as it was when send could not be pressed: nothing went out.
        guard await Task.detached(operation: { GoogleChatWebReader.writeAndSend(text, pid: pid, windowToken: hint) }).value
        else { throw Unavailable() }
        DiagnosticsLog.write(
            "google-chat-web", "reply: send pressed (open \(Self.ms(opened - started)) ms, send \(Self.ms(.now - opened)) ms)"
        )
        confirm(text, target: target, before: before, pid: pid)
        return "Sent"
    }

    /// Watches for the message, then Home; a problem comes as a notice (spec GW-30, GW-31).
    private func confirm(_ text: String, target: String, before: Set<String>, pid: pid_t) {
        let wanted = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pressed = ContinuousClock.now
        replyConfirmation = Task { [weak self] in
            guard let self else { return }
            let arrived = await self.waitFor(pid, timeout: Self.confirmTimeout) { snapshot in
                snapshot.openID == target && snapshot.messages.contains { !before.contains($0.id) && $0.text.contains(wanted) }
            }
            guard !Task.isCancelled else { return }
            guard arrived != nil else {
                DiagnosticsLog.write("google-chat-web", "reply: not confirmed")
                self.refresh()
                self.onReplyProblem?("Not sent? It didn't show up in Google Chat: check there.")
                return
            }
            DiagnosticsLog.write("google-chat-web", "reply: confirmed in \(Self.ms(.now - pressed)) ms")
            let hint = self.windowTokenHint
            let home = await Task.detached { GoogleChatWebReader.goHome(pid: pid, windowToken: hint) }.value
            DiagnosticsLog.write("google-chat-web", home ? "reply: back to Home" : "reply: Home not found")
            self.refresh()
        }
    }

    nonisolated static func ms(_ duration: Duration) -> Int {
        Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
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
