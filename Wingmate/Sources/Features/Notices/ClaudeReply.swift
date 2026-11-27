import Foundation

/// A question or permission request of Claude Code that can be answered from the notch: the hook
/// waits for a reply file next to its input (spec CQ-5, CQ-6).
struct ClaudeReplyRequest: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// AskUserQuestion: the question's text and the tool's whole input as JSON.
        case question(text: String, toolInput: Data)
        case permission
    }

    /// Where the waiting hook looks for the answer.
    let replyPath: String
    let kind: Kind
    /// The buttons: the options' labels, or Allow and Deny.
    let choices: [String]

    static let allow = "Allow"
    static let deny = "Deny"
    /// The hook stops waiting after this long (spec CQ-6); the buttons go a little before.
    static let waits: TimeInterval = 118
    static let maxChoices = 4

    /// Builds the request from the hook's input, or nil when the notch cannot answer it.
    static func request(from input: [String: Any], replyPath: String) -> ClaudeReplyRequest? {
        switch input["hook_event_name"] as? String {
        case "PreToolUse":
            guard input["tool_name"] as? String == "AskUserQuestion",
                  let toolInput = input["tool_input"] as? [String: Any],
                  let questions = toolInput["questions"] as? [[String: Any]], questions.count == 1,
                  let question = questions.first, question["multiSelect"] as? Bool != true,
                  let text = question["question"] as? String,
                  let data = try? JSONSerialization.data(withJSONObject: toolInput)
            else { return nil }
            let labels = (question["options"] as? [[String: Any]] ?? []).compactMap { $0["label"] as? String }
            guard (1...maxChoices).contains(labels.count) else { return nil }
            return ClaudeReplyRequest(replyPath: replyPath, kind: .question(text: text, toolInput: data), choices: labels)
        case "PermissionRequest":
            return ClaudeReplyRequest(replyPath: replyPath, kind: .permission, choices: [allow, deny])
        default:
            return nil
        }
    }

    /// What the hook prints for a choice; empty means "ask in Claude Code as usual".
    func reply(choice: String?) -> Data {
        guard let choice, choices.contains(choice) else { return Data() }
        let output: [String: Any]
        switch kind {
        case .question(let text, let toolInput):
            guard var updated = (try? JSONSerialization.jsonObject(with: toolInput)) as? [String: Any] else { return Data() }
            updated["answers"] = [text: choice]
            output = ["hookEventName": "PreToolUse", "permissionDecision": "allow", "updatedInput": updated]
        case .permission:
            let decision: [String: Any] = choice == Self.allow
                ? ["behavior": "allow"]
                : ["behavior": "deny", "message": "Denied from Wingmate"]
            output = ["hookEventName": "PermissionRequest", "decision": decision]
        }
        return (try? JSONSerialization.data(withJSONObject: ["hookSpecificOutput": output])) ?? Data()
    }

    /// Hands the answer to the waiting hook (written aside, then moved, so it never reads half).
    func send(choice: String?) {
        let target = URL(fileURLWithPath: replyPath)
        let temporary = target.appendingPathExtension("tmp")
        do {
            try reply(choice: choice).write(to: temporary)
            try FileManager.default.moveItem(at: temporary, to: target)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
        }
        let kind = switch (choice, self.kind) {
        case (nil, _): "pass"
        case (_, .question): "option"
        case (let choice?, .permission): choice.lowercased()
        }
        DiagnosticsLog.append("claude-hook", "reply: \(kind)")
    }

    /// The asked action in one line (spec CQ-5): the command, the file, the domain or the tool.
    static func permissionText(from input: [String: Any]) -> String {
        let tool = input["tool_name"] as? String ?? ""
        let toolInput = input["tool_input"] as? [String: Any] ?? [:]
        switch tool {
        case "Bash":
            let command = toolInput["command"] as? String ?? ""
            return String(command.split(whereSeparator: \.isNewline).first ?? "")
        case "Edit", "Write", "MultiEdit", "NotebookEdit", "Read":
            let path = toolInput["file_path"] as? String ?? toolInput["notebook_path"] as? String ?? ""
            return path.isEmpty ? tool : "\(tool) \((path as NSString).lastPathComponent)"
        case "WebFetch":
            let host = (toolInput["url"] as? String).flatMap { URL(string: $0)?.host } ?? ""
            return host.isEmpty ? tool : "Fetch \(host)"
        default:
            return tool
        }
    }
}
