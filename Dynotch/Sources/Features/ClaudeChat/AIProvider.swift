import Foundation

/// The AI module's two services (spec AI-1): Claude through Claude Code, ChatGPT through the
/// Codex program in the ChatGPT app, each with the account the Mac is signed in with.
enum AIProvider: String, Codable, CaseIterable, Sendable {
    case claude
    case chatgpt

    var title: String {
        switch self {
        case .claude: "Claude"
        case .chatgpt: "ChatGPT"
        }
    }

    /// The models to choose from (spec AI-2): Claude's by alias, ChatGPT's from the list Codex
    /// keeps for the signed-in account.
    func models() -> [AIModel] {
        switch self {
        case .claude:
            [AIModel(id: "opus", title: "Opus"), AIModel(id: "sonnet", title: "Sonnet"), AIModel(id: "haiku", title: "Haiku")]
        case .chatgpt:
            CodexCLI.models()
        }
    }
}

struct AIModel: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
}

/// Finds and runs Codex, the ChatGPT app's command line program (spec AI-3).
enum CodexCLI {
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex") }

    static func locate() -> URL? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            home.appendingPathComponent("plugins/.plugin-appserver/codex").path,
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex"
        ]
        return candidates.first(where: FileManager.default.isExecutableFile(atPath:)).map { URL(fileURLWithPath: $0) }
    }

    /// The models Codex lists for the account (its cache), the default first.
    static func models(in file: URL = home.appendingPathComponent("models_cache.json")) -> [AIModel] {
        guard let data = try? Data(contentsOf: file),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = root["models"] as? [[String: Any]]
        else { return [] }
        return models.compactMap { model in
            guard model["visibility"] as? String != "hide", let slug = model["slug"] as? String else { return nil }
            return AIModel(id: slug, title: model["display_name"] as? String ?? slug)
        }
    }

    /// A plain conversation: read-only, without the user's rules, JSON lines out (spec AI-3).
    static func arguments(prompt: String, threadID: String?, model: String?, thinksHarder: Bool, images: [URL]) -> [String] {
        var arguments = ["exec"]
        if let threadID { arguments += ["resume", threadID] }
        arguments += ["--json", "--skip-git-repo-check", "-s", "read-only"]
        if let model { arguments += ["-m", model] }
        if thinksHarder { arguments += ["-c", "model_reasoning_effort=\"high\""] }
        for image in images { arguments += ["-i", image.path] }
        arguments.append(prompt)
        return arguments
    }
}

/// Codex's `--json` lines (spec AI-3).
enum CodexStream {
    static func event(fromLine line: String) -> ClaudeStream.Event? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else { return nil }
        switch type {
        case "thread.started":
            return (object["thread_id"] as? String).map { .session($0) }
        case "item.completed", "item.updated":
            guard let item = object["item"] as? [String: Any], item["type"] as? String == "agent_message",
                  let text = item["text"] as? String
            else { return nil }
            return .replace(text)
        case "turn.completed":
            return .result(text: "", sessionID: nil, isError: false)
        case "turn.failed", "error":
            let error = object["error"] as? [String: Any]
            let message = error?["message"] as? String ?? object["message"] as? String ?? "ChatGPT could not answer."
            return .result(text: message, sessionID: nil, isError: true)
        default:
            return nil
        }
    }
}

/// ChatGPT's limits from Codex's own session logs (spec AI-6): no network, no login data.
enum CodexUsage {
    /// The newest limits Codex wrote, as usage rows.
    nonisolated static func read(now: Date = Date()) -> [UsageLimit] {
        let sessions = CodexCLI.home.appendingPathComponent("sessions")
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: sessions, includingPropertiesForKeys: keys) else { return [] }
        let files = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }
        func modified(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        for file in files.sorted(by: { modified($0) > modified($1) }).prefix(5) {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n").reversed() where line.contains("\"rate_limits\"") {
                if let limits = limits(fromLine: String(line)), !limits.isEmpty { return limits }
            }
        }
        return []
    }

    nonisolated static func limits(fromLine line: String) -> [UsageLimit]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rates = find("rate_limits", in: object) as? [String: Any]
        else { return nil }
        return ["primary", "secondary"].compactMap { key in
            guard let window = rates[key] as? [String: Any], let used = window["used_percent"] as? Double else { return nil }
            let minutes = window["window_minutes"] as? Double ?? 0
            let reset = (window["resets_at"] as? Double).map { Date(timeIntervalSince1970: $0) }
            return UsageLimit(id: "gpt_" + key, title: "ChatGPT · " + title(minutes: minutes), utilization: used, resetsAt: reset)
        }
    }

    nonisolated static func title(minutes: Double) -> String {
        switch minutes {
        case ..<1: "Limit"
        case ..<(24 * 60): "\(Int((minutes / 60).rounded())) hours"
        case ..<(8 * 24 * 60): "week"
        default: "\(Int((minutes / 1440).rounded())) days"
        }
    }

    /// The value under `key` anywhere in the object.
    private nonisolated static func find(_ key: String, in value: Any) -> Any? {
        if let dictionary = value as? [String: Any] {
            if let found = dictionary[key] { return found }
            for nested in dictionary.values { if let found = find(key, in: nested) { return found } }
        } else if let array = value as? [Any] {
            for nested in array { if let found = find(key, in: nested) { return found } }
        }
        return nil
    }
}
