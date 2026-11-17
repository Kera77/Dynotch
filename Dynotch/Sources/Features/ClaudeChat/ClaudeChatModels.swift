import Foundation

struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    var id = UUID()
    let role: Role
    var text: String
    var date = Date()
    /// The answer could not be produced; `text` says why.
    var isError = false
    /// Starred, listed under Favorites (spec AI-15).
    var isFavorite: Bool?
}

/// One conversation with Claude in the notch (spec CC-1).
struct ClaudeChat: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String
    /// Claude Code's session, to continue the conversation with its context.
    var sessionID: String?
    var messages: [ChatMessage] = []
    var updated = Date()
    /// The folder the session belongs to (chats taken over from Claude Code, spec CC-6).
    var workingDirectory: String?
    /// The Claude Code session this chat was taken over from.
    var importedFrom: String?
    /// The next question continues a copy of the session, so the original stays untouched.
    var needsFork: Bool?
    /// Which service answers (spec AI-1); nil: Claude, as before.
    var provider: AIProvider?
    /// The chosen model (spec AI-2); nil: the service's default.
    var model: String?
    /// Kept at the top of the list (spec AI-11).
    var isPinned: Bool?

    var service: AIProvider { provider ?? .claude }

    /// The first line of the first question, shortened.
    static func title(for prompt: String) -> String {
        let line = prompt.split(whereSeparator: \.isNewline).first.map(String.init) ?? prompt
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : (trimmed.isEmpty ? "New chat" : trimmed)
    }
}

/// What Claude Code prints in `--output-format stream-json`, one JSON object per line.
enum ClaudeStream {
    enum Event: Equatable, Sendable {
        /// More text of the answer.
        case delta(String)
        /// The run ended: the whole answer (or the error), and the session to resume later.
        case result(text: String, sessionID: String?, isError: Bool)
        /// The whole answer so far (Codex sends it in pieces, each complete).
        case replace(String)
        /// The session to resume later, known before the end (Codex).
        case session(String)
    }

    static func event(fromLine line: String) -> Event? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else { return nil }
        switch type {
        case "stream_event":
            guard let event = object["event"] as? [String: Any], event["type"] as? String == "content_block_delta",
                  let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
                  let text = delta["text"] as? String
            else { return nil }
            return .delta(text)
        case "result":
            return .result(
                text: object["result"] as? String ?? "",
                sessionID: object["session_id"] as? String,
                isError: object["is_error"] as? Bool ?? false
            )
        default:
            return nil
        }
    }
}

/// Finds the Claude Code program: the chat runs through it, with the login it already has
/// (spec CC-2).
enum ClaudeCLI {
    /// The folder the chats run in; its name also tells Dynotch's own runs from other work.
    static let folderName = "DynotchChat"

    /// Version numbers in a path such as "…/anthropic.claude-code-2.1.325-darwin-arm64/…".
    static func version(inPath path: String) -> [Int] {
        guard let range = path.range(of: #"\d+\.\d+\.\d+"#, options: .regularExpression) else { return [] }
        return path[range].split(separator: ".").compactMap { Int($0) }
    }

    /// The newest of the editor extensions' bundled programs.
    static func newest(of paths: [String]) -> String? {
        paths.max { version(inPath: $0).lexicographicallyPrecedes(version(inPath: $1)) }
    }

    /// The bundled program of the newest editor extension, otherwise an installed `claude`.
    static func locate() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var bundled: [String] = []
        for editor in [".vscode", ".vscode-insiders", ".cursor", ".windsurf"] {
            let folder = "\(home)/\(editor)/extensions"
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
            bundled += names.filter { $0.hasPrefix("anthropic.claude-code-") }
                .map { "\(folder)/\($0)/resources/native-binary/claude" }
        }
        let installed = ["\(home)/.local/bin/claude", "\(home)/.claude/local/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        let executable = FileManager.default.isExecutableFile(atPath:)
        let path = newest(of: bundled.filter(executable)) ?? installed.first(where: executable)
        return path.map { URL(fileURLWithPath: $0) }
    }

    static func arguments(prompt: String, sessionID: String?, fork: Bool = false, model: String? = nil, canRead: Bool = false) -> [String] {
        var arguments = [
            "-p", prompt, "--output-format", "stream-json", "--verbose", "--include-partial-messages",
            // A plain conversation: no tools (only reading attached files), no extra servers.
            "--tools", canRead ? "Read" : "", "--strict-mcp-config",
            "--append-system-prompt", "You are answering in a small chat panel at the Mac's notch. Be concise."
        ]
        if let model { arguments += ["--model", model] }
        if let sessionID { arguments += ["--resume", sessionID] + (fork ? ["--fork-session"] : []) }
        return arguments
    }
}
