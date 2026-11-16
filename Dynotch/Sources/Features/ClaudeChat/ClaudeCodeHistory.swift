import Foundation

/// A conversation found in Claude Code's own history (spec CC-6).
struct ClaudeCodeSession: Identifiable, Equatable, Sendable {
    /// The session id, as `claude --resume` takes it.
    let id: String
    let title: String
    /// The folder the session ran in; it can only be continued from there.
    let workingDirectory: String?
    let file: URL
    let modified: Date
}

/// Reads the sessions Claude Code keeps in ~/.claude/projects (spec CC-6). Conversations of the
/// Claude apps and of claude.ai are stored on Anthropic's servers and cannot be read from here.
enum ClaudeCodeHistory {
    static let maxSessions = 40
    static let maxMessages = 80

    static var projectsFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    }

    /// The newest sessions, without the ones Dynotch's own chat made.
    static func sessions(in folder: URL = projectsFolder) -> [ClaudeCodeSession] {
        let manager = FileManager.default
        let projects = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var found: [ClaudeCodeSession] = []
        for project in projects where !project.lastPathComponent.hasSuffix(ClaudeCLI.folderName) {
            let files = (try? manager.contentsOfDirectory(at: project, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for file in files where file.pathExtension == "jsonl" {
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let head = read(file, fromEnd: false)
                let tail = read(file, fromEnd: true)
                guard let title = title(head: head, tail: tail) else { continue }
                found.append(ClaudeCodeSession(
                    id: file.deletingPathExtension().lastPathComponent, title: title,
                    workingDirectory: firstValue(of: "cwd", in: head), file: file, modified: modified
                ))
            }
        }
        return Array(found.sorted { $0.modified > $1.modified }.prefix(maxSessions))
    }

    private static func read(_ file: URL, fromEnd: Bool, length: UInt64 = 200_000) -> String {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return "" }
        defer { try? handle.close() }
        if fromEnd {
            let size = (try? handle.seekToEnd()) ?? 0
            try? handle.seek(toOffset: size > length ? size - length : 0)
        }
        let data = (try? handle.read(upToCount: Int(length))) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    /// The title Claude Code gave the session, otherwise its first question.
    static func title(head: String, tail: String) -> String? {
        if let title = lastValue(of: "aiTitle", in: tail) ?? lastValue(of: "aiTitle", in: head), !title.isEmpty {
            return title
        }
        let firstQuestion = head.split(separator: "\n").lazy
            .compactMap { message(fromLine: String($0)) }
            .first { $0.role == .user }
        return firstQuestion.map { ClaudeChat.title(for: $0.text) }
    }

    private static func values(of key: String, in text: String) -> [String] {
        let pattern = "\"\(key)\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            // Undo the JSON escaping of the captured string.
            let quoted = "\"\(text[range])\""
            return (try? JSONSerialization.jsonObject(with: Data(quoted.utf8), options: .fragmentsAllowed)) as? String
        }
    }

    private static func firstValue(of key: String, in text: String) -> String? { values(of: key, in: text).first }
    private static func lastValue(of key: String, in text: String) -> String? { values(of: key, in: text).last }

    /// What was said in the session: the questions and the written answers, without tool calls,
    /// internal notes and side conversations. The newest `maxMessages`.
    static func messages(in file: URL) -> [ChatMessage] {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return messages(inTranscript: text)
    }

    static func messages(inTranscript text: String) -> [ChatMessage] {
        var result: [ChatMessage] = []
        for line in text.split(separator: "\n") {
            guard let message = message(fromLine: String(line)) else { continue }
            // Consecutive pieces of one answer belong together.
            if let last = result.indices.last, result[last].role == .assistant, message.role == .assistant {
                result[last].text += "\n\n" + message.text
            } else {
                result.append(message)
            }
        }
        return Array(result.suffix(maxMessages))
    }

    static func message(fromLine line: String) -> ChatMessage? {
        guard line.contains("\"type\":\"user\"") || line.contains("\"type\":\"assistant\""),
              let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let type = object["type"] as? String, let role = ChatMessage.Role(rawValue: type),
              object["isSidechain"] as? Bool != true, object["isMeta"] as? Bool != true,
              let message = object["message"] as? [String: Any]
        else { return nil }
        var text = ""
        if let content = message["content"] as? String {
            text = content
        } else if let blocks = message["content"] as? [[String: Any]] {
            text = blocks.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined(separator: "\n")
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Commands, reminders and notifications are wrapped in tags; they are not conversation.
        guard !text.isEmpty, !(role == .user && text.hasPrefix("<")) else { return nil }
        let date = (object["timestamp"] as? String).flatMap(ClaudeUsageParser.date(from:)) ?? Date()
        return ChatMessage(role: role, text: text, date: date)
    }
}
