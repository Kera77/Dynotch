import Foundation

/// Claude Code (in a terminal, VS Code or the Claude app) asks a question or waits for a
/// permission: hooks open dynotch:// links, and a notice hangs under the notch until it is
/// answered (spec CQ-1…CQ-4).
enum ClaudeQuestionHook {
    enum Event: Equatable {
        case asks(StickyNotice)
        case answered
        /// A hook link that is not a question (e.g. "waiting for your input").
        case ignored
    }

    static let askMarker = "dynotch://claude-asks"
    static let answeredMarker = "dynotch://claude-answered"
    private static let filePrefix = "dynotch-ask."

    /// Keeps the hook's input in a temporary file whose name travels in the link, notes that a
    /// question is open, and names the app it runs in (`__CFBundleIdentifier`, inherited from it).
    static let askCommand = #"[ -n "$DYNOTCH_CHAT" ] && exit 0; d="${TMPDIR:-/tmp}"; f=$(mktemp "$d/dynotch-ask.XXXXXX") && cat > "$f"; "#
        + #"touch "$d/dynotch-asking"; open -g "dynotch://claude-asks?app=${__CFBundleIdentifier:-}"#
        + #"&project=$(basename "$PWD" | sed 's/ /%20/g')&info=$(basename "$f")"; exit 0"#
    /// After any later step only a check for the file; Dynotch is told once.
    static let answeredCommand = #"cat > /dev/null; m="${TMPDIR:-/tmp}/dynotch-asking"; "#
        + #"[ -f "$m" ] && rm -f "$m" && open -g "dynotch://claude-answered"; exit 0"#

    /// Hook event → (matcher, command). Asking: a question tool or a notification; answered:
    /// the next tool run, a new prompt or the end of the turn.
    static let hooks: [(event: String, matcher: String?, command: String)] = [
        ("PreToolUse", "AskUserQuestion", askCommand),
        ("Notification", nil, askCommand),
        ("PostToolUse", nil, answeredCommand),
        ("UserPromptSubmit", nil, answeredCommand),
        ("Stop", nil, answeredCommand)
    ]

    // MARK: - Links

    static func event(from url: URL, now: Date) -> Event? {
        guard url.scheme?.lowercased() == "dynotch" else { return nil }
        switch url.host?.lowercased() {
        case "claude-answered":
            return .answered
        case "claude-asks":
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            func value(_ name: String) -> String? {
                items.first { $0.name == name }?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let input = hookInput(named: value("info")), let question = question(from: input) else { return .ignored }
            let project = value("project") ?? ""
            guard project != ClaudeCLI.folderName else { return .ignored }
            let app = value("app").flatMap { $0.isEmpty ? nil : $0 }
            DiagnosticsLog.append("claude-hook", "asks: \(question.title) app=\(app ?? "-")")
            return .asks(StickyNotice(
                title: question.title, detail: question.text.isEmpty ? project : question.text, date: now,
                isQuestion: true, appIdentifier: app
            ))
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

    private static func oneLine(_ text: String) -> String {
        String(text.split(whereSeparator: \.isNewline).joined(separator: " ").prefix(160))
    }

    /// The hook's input from the temporary file named in the link (which is removed).
    private static func hookInput(named name: String?) -> [String: Any]? {
        guard let name, name.hasPrefix(filePrefix), !name.contains("/") else { return nil }
        for folder in [NSTemporaryDirectory(), "/tmp/"] {
            let file = URL(fileURLWithPath: folder).appendingPathComponent(name)
            guard let data = try? Data(contentsOf: file) else { continue }
            try? FileManager.default.removeItem(at: file)
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        return nil
    }

    // MARK: - Claude Code settings

    private static func isOurs(_ group: [String: Any]) -> Bool {
        (group["hooks"] as? [[String: Any]] ?? []).contains { hook in
            let command = hook["command"] as? String ?? ""
            return command.contains(askMarker) || command.contains(answeredMarker)
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
                    var group: [String: Any] = ["hooks": [["type": "command", "command": hook.command]]]
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
