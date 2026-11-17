@testable import Dynotch
import Foundation
import Testing

/// v0.36: a notice when Claude Code asks a question or needs a permission (spec CQ-1…CQ-4).
struct V036Tests {
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
}
