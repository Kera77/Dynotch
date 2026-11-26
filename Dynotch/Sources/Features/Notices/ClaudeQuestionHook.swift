import Foundation

/// Claude Code (in a terminal, VS Code or the Claude app) asks a question or waits for a
/// permission: hooks open dynotch:// links, and a notice hangs under the notch until it is
/// answered (spec CQ-1…CQ-7). The session hooks feed the Sessions tab (spec CS-3).
enum ClaudeQuestionHook {
    enum Event: Equatable {
        case asks(StickyNotice, session: String?)
        case answered(session: String?)
        case session(ClaudeSessionEvent)
        /// A hook link that is not a question (e.g. "waiting for your input").
        case ignored
    }

    static let askMarker = "dynotch://claude-asks"
    static let answeredMarker = "dynotch://claude-answered"
    static let sessionMarker = "dynotch://claude-session"
    private static let filePrefix = "dynotch-ask."
    private static let sessionPrefix = "dynotch-session."
    /// The hook waits a little longer than Wingmate offers its buttons (spec CQ-6).
    static let replyTimeout = 130

    private static let skipChat = #"[ -n "$DYNOTCH_CHAT" ] && exit 0; d="${TMPDIR:-/tmp}"; "#
    private static let project = #"&project=$(basename "$PWD" | sed 's/ /%20/g')"#

    /// Keeps the hook's input in a temporary file whose name travels in the link, notes that a
    /// question is open, and names the app it runs in (`__CFBundleIdentifier`, inherited from it).
    static let askCommand = skipChat + #"f=$(mktemp "$d/dynotch-ask.XXXXXX") && cat > "$f"; "#
        + #"touch "$d/dynotch-asking"; open -g "dynotch://claude-asks?app=${__CFBundleIdentifier:-}"#
        + project + #"&info=$(basename "$f")"; exit 0"#
    /// The same, then waits up to 120 s for Wingmate's answer and prints it (spec CQ-6).
    static let replyCommand = skipChat + #"f=$(mktemp "$d/dynotch-ask.XXXXXX") && cat > "$f" || exit 0; "#
        + #"touch "$d/dynotch-asking"; r="$f.reply"; open -g "dynotch://claude-asks?app=${__CFBundleIdentifier:-}"#
        + project + #"&info=$(basename "$f")&reply=1"; i=0; "#
        + #"while [ ! -f "$r" ] && [ $i -lt 1200 ]; do sleep 0.1; i=$((i+1)); done; "#
        + #"[ -f "$r" ] && cat "$r"; rm -f "$r"; exit 0"#
    /// After any later step only a check for the file; Dynotch is told once, with the session.
    static let answeredCommand = #"i=$(cat); m="${TMPDIR:-/tmp}/dynotch-asking"; "#
        + #"[ -f "$m" ] && rm -f "$m" && open -g "dynotch://claude-answered?session=$(printf %s "$i" "#
        + #"| sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p' | head -1)"; exit 0"#
    /// A session started, got a prompt, stopped or ended (spec CS-3).
    static let sessionCommand = skipChat + #"f=$(mktemp "$d/dynotch-session.XXXXXX") && cat > "$f"; "#
        + #"open -g "dynotch://claude-session?app=${__CFBundleIdentifier:-}"# + project
        + #"&info=$(basename "$f")"; exit 0"#

    /// Hook event → (matcher, command). Asking: a question tool, a permission or a notification;
    /// answered: the next tool run, a new prompt or the end of the turn; and the session's steps.
    struct Hook: Sendable {
        let event: String
        var matcher: String?
        let command: String
        var timeout: Int?
    }

    static let hooks: [Hook] = [
        Hook(event: "PreToolUse", matcher: "AskUserQuestion", command: replyCommand, timeout: replyTimeout),
        Hook(event: "PermissionRequest", command: replyCommand, timeout: replyTimeout),
        Hook(event: "Notification", command: askCommand),
        Hook(event: "PostToolUse", command: answeredCommand),
        Hook(event: "UserPromptSubmit", command: answeredCommand),
        Hook(event: "Stop", command: answeredCommand)
    ] + ["SessionStart", "UserPromptSubmit", "Stop", "SessionEnd"].map { Hook(event: $0, command: sessionCommand) }

    // MARK: - Links

    static func event(from url: URL, now: Date) -> Event? {
        guard url.scheme?.lowercased() == "dynotch" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let app = value("app").flatMap { $0.isEmpty ? nil : $0 }
        let project = value("project") ?? ""
        switch url.host?.lowercased() {
        case "claude-answered":
            return .answered(session: value("session").flatMap { $0.isEmpty ? nil : $0 })
        case "claude-session":
            guard project != ClaudeCLI.folderName,
                  let (input, _) = hookInput(named: value("info"), prefix: sessionPrefix),
                  let event = ClaudeSessionEvent(input: input, app: app, date: now)
            else { return .ignored }
            return .session(event)
        case "claude-asks":
            guard let (input, file) = hookInput(named: value("info"), prefix: filePrefix) else { return .ignored }
            let reply = value("reply") == "1" ? ClaudeReplyRequest.request(from: input, replyPath: file.path + ".reply") : nil
            guard project != ClaudeCLI.folderName, let question = question(from: input) else {
                // Never leave a waiting hook hanging.
                reply?.send(choice: nil)
                return .ignored
            }
            DiagnosticsLog.append("claude-hook", "asks: \(question.title) app=\(app ?? "-") buttons=\(reply != nil)")
            var notice = StickyNotice(
                title: question.title, detail: question.text.isEmpty ? project : question.text, date: now,
                isQuestion: true, appIdentifier: app
            )
            notice.reply = reply
            return .asks(notice, session: input["session_id"] as? String)
        default:
            return nil
        }
    }

    /// What the hook's input asks, or nil if it does not wait for an answer.
    static func question(from input: [String: Any]) -> (title: String, text: String)? {
        switch input["hook_event_name"] as? String {
        case "PreToolUse":
            guard input["tool_name"] as? String == "AskUserQuestion" else { return nil }
            let questions = (input["tool_input"] as? [String: Any])?["questions"] as? [[String: Any]] ?? []
            let text = oneLine(questions.first?["question"] as? String ?? "")
            return ("Claude asks", questions.count > 1 ? "\(text) (+\(questions.count - 1))" : text)
        case "PermissionRequest":
            return ("Claude needs you", oneLine(ClaudeReplyRequest.permissionText(from: input)))
        case "Notification":
            let message = oneLine(input["message"] as? String ?? "")
            let waits: Bool
            if let type = input["notification_type"] as? String {
                waits = ["permission_prompt", "elicitation_dialog"].contains(type)
            } else {
                waits = message.lowercased().contains("permission")
            }
            return waits ? ("Claude needs you", message) : nil
        default:
            return nil
        }
    }

    static func oneLine(_ text: String, limit: Int = 160) -> String {
        String(text.split(whereSeparator: \.isNewline).joined(separator: " ").prefix(limit))
    }

    /// The hook's input from the temporary file named in the link (which is removed), and where it was.
    private static func hookInput(named name: String?, prefix: String) -> ([String: Any], URL)? {
        guard let name, name.hasPrefix(prefix), !name.contains("/") else { return nil }
        for folder in [NSTemporaryDirectory(), "/tmp/"] {
            let file = URL(fileURLWithPath: folder).appendingPathComponent(name)
            guard let data = try? Data(contentsOf: file) else { continue }
            try? FileManager.default.removeItem(at: file)
            guard let input = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
            return (input, file)
        }
        return nil
    }

    // MARK: - Claude Code settings

    private static func isOurs(_ group: [String: Any]) -> Bool {
        (group["hooks"] as? [[String: Any]] ?? []).contains { hook in
            let command = hook["command"] as? String ?? ""
            return [askMarker, answeredMarker, sessionMarker].contains { command.contains($0) }
        }
    }

    static func isInstalled(in settings: [String: Any]) -> Bool {
        let groups = (settings["hooks"] as? [String: Any])?["PreToolUse"] as? [[String: Any]] ?? []
        return groups.contains(where: isOurs)
    }

    static func isInstalled() -> Bool {
        (try? ClaudeHook.read()).map(isInstalled(in:)) ?? false
    }

    /// The settings with (or without) Dynotch's question hooks; everything else is kept.
    static func settings(_ settings: [String: Any], installed: Bool) -> [String: Any] {
        var result = settings
        var hooks = result["hooks"] as? [String: Any] ?? [:]
        for event in Set(Self.hooks.map(\.event)) {
            var groups = (hooks[event] as? [[String: Any]] ?? []).filter { !isOurs($0) }
            if installed {
                for hook in Self.hooks where hook.event == event {
                    var entry: [String: Any] = ["type": "command", "command": hook.command]
                    if let timeout = hook.timeout { entry["timeout"] = timeout }
                    var group: [String: Any] = ["hooks": [entry]]
                    if let matcher = hook.matcher { group["matcher"] = matcher }
                    groups.append(group)
                }
            }
            hooks[event] = groups.isEmpty ? nil : groups
        }
        result["hooks"] = hooks.isEmpty ? nil : hooks
        return result
    }

    static func setInstalled(_ installed: Bool) throws {
        try ClaudeHook.write(settings(try ClaudeHook.read(), installed: installed))
    }

    /// Rewrites installed hooks that still have older commands.
    static func upgradeIfNeeded() {
        guard let current = try? ClaudeHook.read(), isInstalled(in: current) else { return }
        let updated = settings(current, installed: true)
        if !NSDictionary(dictionary: updated).isEqual(to: current) { try? ClaudeHook.write(updated) }
    }
}
