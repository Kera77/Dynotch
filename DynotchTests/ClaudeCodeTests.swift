import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// Claude Code and Codex hooks: finished, questions, transcripts and history (spec CN-3, CN-4, CQ-1…CQ-4, CC-6).
@MainActor
struct ClaudeCodeTests {
    @Test func backgroundWorkStillRunningIsFound() {
        let running = #"{"content":"Command running in background with ID: abc123. Output is being written"}"#
        #expect(ClaudeTranscript.pendingTasks(in: running) == ["abc123"])

        let reported = running + "\n" + #"{"text":"<task-notification>\n<task-id>abc123</task-id>\n<status>completed</status>"}"#
        #expect(ClaudeTranscript.pendingTasks(in: reported).isEmpty)

        let stopped = running + "\n" + #"{"type":"tool_use","name":"TaskStop","input":{"task_id":"abc123"}}"#
        #expect(ClaudeTranscript.pendingTasks(in: stopped).isEmpty)

        let two = running + "\n" + #"{"content":"Command running in background with ID: zz9"}"# + "\n<task-id>abc123</task-id>"
        #expect(ClaudeTranscript.pendingTasks(in: two) == ["zz9"])
        #expect(ClaudeTranscript.pendingTasks(in: "nothing here").isEmpty)

        // A piece cut out of a file: the halves of lines (and of characters) at its ends are dropped.
        let bytes = Data("ő-first\nsecond\nthird-ő".utf8)
        let piece = bytes.dropFirst(1).dropLast(1)
        #expect(ClaudeTranscript.wholeLines(in: Data(piece), cutAtStart: true, cutAtEnd: true) == "second")
        #expect(ClaudeTranscript.wholeLines(in: bytes, cutAtStart: false, cutAtEnd: false) == "ő-first\nsecond\nthird-ő")
    }

    @Test func theHookNamesTheTranscriptThroughAFile() throws {
        let name = "dynotch-stop.\(UUID().uuidString.prefix(6))"
        let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        try Data(#"{"transcript_path":"/tmp/session.jsonl","session_id":"s"}"#.utf8).write(to: file)
        let url = try #require(URL(string: "dynotch://claude-finished?project=App&info=\(name)"))
        #expect(ClaudeHook.transcriptPath(from: url) == "/tmp/session.jsonl")
        // Read once, then removed.
        #expect(!FileManager.default.fileExists(atPath: file.path))
        let unsafe = try #require(URL(string: "dynotch://claude-finished?info=../etc/passwd"))
        #expect(ClaudeHook.transcriptPath(from: unsafe) == nil)
        let plain = try #require(URL(string: "dynotch://claude-finished?project=App"))
        #expect(ClaudeHook.transcriptPath(from: plain) == nil)
        #expect(ClaudeHook.command.contains("DYNOTCH_CHAT"))
    }

    @Test func sessionsAreReadWithoutToolTraffic() {
        let transcript = [
            #"{"type":"user","isSidechain":false,"cwd":"/Users/x/App","message":"#
                + #"{"role":"user","content":[{"type":"text","text":"Build a notch app"}]}}"#,
            #"{"type":"assistant","isSidechain":false,"message":{"content":[{"type":"thinking","thinking":"hm"}]}}"#,
            #"{"type":"assistant","isSidechain":false,"message":{"content":[{"type":"text","text":"Sure."}]}}"#,
            #"{"type":"assistant","isSidechain":false,"message":{"content":[{"type":"tool_use","name":"Bash","input":{}}]}}"#,
            #"{"type":"user","isSidechain":false,"message":{"content":[{"type":"tool_result","content":"ok"}]}}"#,
            #"{"type":"assistant","isSidechain":false,"message":{"content":[{"type":"text","text":"Done."}]}}"#,
            #"{"type":"user","isSidechain":false,"message":{"content":"<task-notification>x</task-notification>"}}"#,
            #"{"type":"user","isSidechain":true,"message":{"content":"side question"}}"#,
            #"{"type":"ai-title","aiTitle":"Notch \"app\" build","sessionId":"s"}"#,
            #"{"type":"user","isSidechain":false,"message":{"content":"Thanks"}}"#
        ].joined(separator: "\n")
        let messages = ClaudeCodeHistory.messages(inTranscript: transcript)
        #expect(messages.map(\.role) == [.user, .assistant, .user])
        #expect(messages.map(\.text) == ["Build a notch app", "Sure.\n\nDone.", "Thanks"])
        #expect(ClaudeCodeHistory.title(head: transcript, tail: transcript) == "Notch \"app\" build")
        #expect(ClaudeCodeHistory.title(head: String(transcript.prefix(200)), tail: "") == "Build a notch app")
        #expect(ClaudeCodeHistory.title(head: "", tail: "") == nil)
    }

    @Test func theNoticeNamesTheProjectThatWasWorkedOn() {
        let text = [
            #"{"name":"Edit","input":{"file_path":"/Users/x/Dynotch/Sources/A.swift"}}"#,
            #"{"name":"Bash","input":{"command":"cd /Users/x/Dynotch && git status"}}"#,
            #"{"name":"Read","input":{"file_path":"/Users/x/Other/notes.md"}}"#,
            #"{"name":"Read","input":{"file_path":"/tmp/scratch/out.txt"}}"#
        ].joined(separator: "\n")
        let paths = ClaudeTranscript.workedPaths(in: text)
        #expect(paths.contains("/Users/x/Dynotch/Sources"))
        #expect(paths.contains("/Users/x/Dynotch"))
        let repositories: Set<String> = ["/Users/x/Dynotch", "/Users/x/Other"]
        #expect(ClaudeTranscript.project(amongPaths: paths) { repositories.contains($0) } == "Dynotch")
        #expect(ClaudeTranscript.project(amongPaths: ["/tmp/a"]) { _ in false } == nil)
        #expect(ClaudeTranscript.project(amongPaths: []) { _ in true } == nil)
    }

    @Test func aQuestionToolAsks() throws {
        let input: [String: Any] = [
            "hook_event_name": "PreToolUse", "tool_name": "AskUserQuestion",
            "tool_input": ["questions": [["question": "Which one?\nPick"], ["question": "And?"]]]
        ]
        let question = try #require(ClaudeQuestionHook.question(from: input))
        #expect(question.title == "Claude asks")
        #expect(question.text == "Which one? Pick (+1)")
        #expect(ClaudeQuestionHook.question(from: ["hook_event_name": "PreToolUse", "tool_name": "Bash"]) == nil)
    }

    @Test func onlyPermissionNotificationsAsk() {
        let permission: [String: Any] = [
            "hook_event_name": "Notification", "message": "Claude needs your permission to use Bash",
            "notification_type": "permission_prompt"
        ]
        #expect(ClaudeQuestionHook.question(from: permission)?.title == "Claude needs you")
        let idle: [String: Any] = [
            "hook_event_name": "Notification", "message": "Claude is waiting for your input", "notification_type": "idle_prompt"
        ]
        #expect(ClaudeQuestionHook.question(from: idle) == nil)
        // Older versions send no type: the message decides.
        let untyped: [String: Any] = ["hook_event_name": "Notification", "message": "Claude needs your permission to use Edit"]
        #expect(ClaudeQuestionHook.question(from: untyped) != nil)
    }

    @Test func answeredLinksAndOtherLinks() throws {
        let answered = try #require(URL(string: "dynotch://claude-answered"))
        #expect(ClaudeQuestionHook.event(from: answered, now: Date()) == .answered)
        let finished = try #require(URL(string: "dynotch://claude-finished?project=x"))
        #expect(ClaudeQuestionHook.event(from: finished, now: Date()) == nil)
        let missing = try #require(URL(string: "dynotch://claude-asks?info=dynotch-ask.none"))
        #expect(ClaudeQuestionHook.event(from: missing, now: Date()) == .ignored)
    }

    @Test func installingKeepsOtherHooksAndRemovesCleanly() {
        let other: [String: Any] = ["hooks": [["type": "command", "command": "other-tool Working"]]]
        let original: [String: Any] = ["model": "opus", "hooks": ["PreToolUse": [other]]]
        let installed = ClaudeQuestionHook.settings(original, installed: true)
        #expect(ClaudeQuestionHook.isInstalled(in: installed))
        let hooks = installed["hooks"] as? [String: Any] ?? [:]
        let preToolUse = hooks["PreToolUse"] as? [[String: Any]] ?? []
        #expect(preToolUse.count == 2)
        #expect(preToolUse.last?["matcher"] as? String == "AskUserQuestion")
        #expect(Set(hooks.keys) == ["PreToolUse", "Notification", "PostToolUse", "UserPromptSubmit", "Stop"])

        let removed = ClaudeQuestionHook.settings(installed, installed: false)
        #expect(!ClaudeQuestionHook.isInstalled(in: removed))
        #expect(NSDictionary(dictionary: removed).isEqual(to: original))
    }

    @Test func theHooksAlwaysSucceed() {
        #expect(ClaudeQuestionHook.answeredCommand.hasSuffix("exit 0"))
        #expect(ClaudeQuestionHook.askCommand.hasSuffix("exit 0"))
    }

    @Test func claudeFinishedNamesTheAppItRanIn() throws {
        let url = try #require(URL(string: "dynotch://claude-finished?project=Dynotch&app=com.microsoft.VSCode"))
        let notice = try #require(ClaudeHook.notice(from: url, now: Date()))
        #expect(notice.appIdentifier == "com.microsoft.VSCode")
        let old = try #require(URL(string: "dynotch://claude-finished?project=Dynotch&app="))
        #expect(ClaudeHook.notice(from: old, now: Date())?.appIdentifier == nil)
        #expect(ClaudeHook.command.contains("app=${__CFBundleIdentifier:-}"))
    }

    @Test func codexFinishedIsAChatGPTNotice() throws {
        let url = try #require(URL(string: "dynotch://codex-finished?project=site&app=com.openai.codex"))
        let notice = try #require(CodexHook.notice(from: url, now: Date()))
        #expect(notice.title == "ChatGPT finished")
        #expect(notice.detail == "site")
        #expect(notice.appIdentifier == "com.openai.codex")
        #expect(CodexHook.notice(from: try #require(URL(string: "dynotch://claude-finished?project=x")), now: Date()) == nil)
    }

    @Test func codexHookKeepsOtherAppsHooks() {
        let other: [String: Any] = ["hooks": ["Stop": [["hooks": [["type": "command", "command": "bartender.sh"]]]]]]
        let installed = CodexHook.hooks(other, installed: true)
        #expect(CodexHook.isInstalled(in: installed))
        let stop = ((installed["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]) ?? []
        #expect(stop.count == 2)
        let removed = CodexHook.hooks(installed, installed: false)
        #expect(!CodexHook.isInstalled(in: removed))
        #expect((((removed["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]) ?? []).count == 1)
    }

    @Test func codexHooksFeatureIsTurnedOnOnce() {
        let isOn = "[features]\ncodex_hooks = true  # other\n"
        #expect(CodexHook.configWithHooksOn(isOn) == isOn)
        let features = CodexHook.configWithHooksOn("model = \"x\"\n[features]\nfoo = 1\n")
        #expect(features.contains("[features]\ncodex_hooks = true"))
        let none = CodexHook.configWithHooksOn("model = \"x\"\n")
        #expect(none.hasPrefix("codex_hooks = true"))
        let off = CodexHook.configWithHooksOn("[features]\ncodex_hooks = false\n")
        #expect(off.contains("codex_hooks = true") && !off.contains("false"))
    }

    @Test func theProjectsWindowIsFoundByTitle() {
        let titles = ["notes.md — Other", "NotchView.swift — Dynotch", "Dynotch-old"]
        #expect(NoticeApp.window(among: titles, naming: "Dynotch") == 1)
        #expect(NoticeApp.window(among: ["a — egy-50-000"], naming: "egy-50-000") == 0)
        #expect(NoticeApp.window(among: titles, naming: "Missing") == nil)
    }
}
