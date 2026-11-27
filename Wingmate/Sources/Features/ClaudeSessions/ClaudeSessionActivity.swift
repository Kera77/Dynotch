import Foundation

/// What a Claude Code session is doing, read from the end of its transcript (spec CS-11): the
/// step it runs now, and the first line of its last answer. Nothing of it is logged.
enum ClaudeSessionActivity {
    /// Only the end of the transcript is read.
    static let tailLength = 200_000

    struct Reading: Equatable, Sendable {
        var activity: String?
        var answer: String?
    }

    static func read(fileAt path: String) -> Reading {
        guard let handle = FileHandle(forReadingAtPath: path) else { return Reading() }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > UInt64(tailLength) ? size - UInt64(tailLength) : 0)
        let data = (try? handle.readToEnd()) ?? Data()
        return parse(ClaudeTranscript.wholeLines(in: data, cutAtStart: size > UInt64(tailLength), cutAtEnd: false))
    }

    /// The newest assistant entry tells the step (its last tool call); the newest text is the answer.
    static func parse(_ text: String) -> Reading {
        var reading = Reading()
        var sawAssistant = false
        for line in text.split(separator: "\n").reversed() {
            guard line.contains("\"assistant\""), let data = line.data(using: .utf8),
                  let entry = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  entry["type"] as? String == "assistant", entry["isSidechain"] as? Bool != true,
                  let content = (entry["message"] as? [String: Any])?["content"] as? [[String: Any]]
            else { continue }
            if !sawAssistant {
                sawAssistant = true
                if let tool = content.last(where: { $0["type"] as? String == "tool_use" }) {
                    reading.activity = describe(tool: tool["name"] as? String ?? "", input: tool["input"] as? [String: Any] ?? [:])
                }
            }
            if let answer = content.compactMap({ $0["type"] as? String == "text" ? $0["text"] as? String : nil })
                .compactMap(firstLine).last {
                reading.answer = answer
                break
            }
        }
        return reading
    }

    /// "Editing NotchView.swift", "Running: Build the app", "Searching the code"…
    static func describe(tool: String, input: [String: Any]) -> String {
        let file = (input["file_path"] as? String ?? input["notebook_path"] as? String).map { ($0 as NSString).lastPathComponent }
        switch tool {
        case "Edit", "MultiEdit", "Write", "NotebookEdit": return file.map { "Editing \($0)" } ?? "Editing a file"
        case "Read": return file.map { "Reading \($0)" } ?? "Reading a file"
        case "Bash":
            guard let what = (input["description"] as? String).flatMap(firstLine) else { return "Running a command" }
            return "Running: " + what
        case "Grep", "Glob", "LS": return "Searching the code"
        case "WebFetch", "WebSearch": return "Looking on the web"
        case "Task", "Agent": return "Running an agent"
        case "TodoWrite": return "Planning the steps"
        default: return tool.isEmpty ? "Working" : "Using \(tool)"
        }
    }

    /// The first line with words, without Markdown marks, at most 120 characters.
    static func firstLine(_ text: String) -> String? {
        let marks = CharacterSet(charactersIn: "#*>`-_ ").union(.whitespaces)
        for line in text.split(whereSeparator: \.isNewline) {
            let clean = line.trimmingCharacters(in: marks).replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
            if !clean.isEmpty { return String(clean.prefix(120)) }
        }
        return nil
    }
}
