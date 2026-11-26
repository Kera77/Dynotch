@testable import Dynotch
import Foundation
import Testing

/// Answers from the notch and the Sessions tab (spec CQ-5, CQ-6, CS-1…CS-3).
@MainActor
struct ClaudeSessionTests {
    private func question(options: [String], multiSelect: Bool = false, count: Int = 1) -> [String: Any] {
        let one: [String: Any] = [
            "question": "Which colour?", "header": "Colour", "multiSelect": multiSelect,
            "options": options.map { ["label": $0, "description": ""] }
        ]
        return [
            "hook_event_name": "PreToolUse", "tool_name": "AskUserQuestion", "session_id": "s1",
            "tool_input": ["questions": Array(repeating: one, count: count)]
        ]
    }

    @Test func aSingleQuestionGetsButtonsAndAnAnswer() throws {
        let request = try #require(ClaudeReplyRequest.request(from: question(options: ["Red", "Blue"]), replyPath: "/tmp/x.reply"))
        #expect(request.choices == ["Red", "Blue"])
        let output = try #require(try JSONSerialization.jsonObject(with: request.reply(choice: "Blue")) as? [String: Any])
        let specific = try #require(output["hookSpecificOutput"] as? [String: Any])
        #expect(specific["permissionDecision"] as? String == "allow")
        let updated = try #require(specific["updatedInput"] as? [String: Any])
        #expect(updated["answers"] as? [String: String] == ["Which colour?": "Blue"])
        #expect((updated["questions"] as? [[String: Any]])?.count == 1)
        // A pass, or a choice it does not offer, lets Claude Code ask as usual.
        #expect(request.reply(choice: nil).isEmpty)
        #expect(request.reply(choice: "Green").isEmpty)
    }

    @Test func onlySimpleQuestionsGetButtons() {
        #expect(ClaudeReplyRequest.request(from: question(options: ["A", "B"], multiSelect: true), replyPath: "p") == nil)
        #expect(ClaudeReplyRequest.request(from: question(options: ["A", "B"], count: 2), replyPath: "p") == nil)
        #expect(ClaudeReplyRequest.request(from: question(options: ["A", "B", "C", "D", "E"]), replyPath: "p") == nil)
    }

    @Test func permissionsAllowOrDeny() throws {
        let input: [String: Any] = [
            "hook_event_name": "PermissionRequest", "tool_name": "Bash",
            "tool_input": ["command": "rm -rf build\necho done"]
        ]
        #expect(ClaudeQuestionHook.question(from: input)?.title == "Claude needs you")
        #expect(ClaudeReplyRequest.permissionText(from: input) == "rm -rf build")
        let request = try #require(ClaudeReplyRequest.request(from: input, replyPath: "p"))
        #expect(request.choices == ["Allow", "Deny"])
        let deny = try #require(try JSONSerialization.jsonObject(with: request.reply(choice: "Deny")) as? [String: Any])
        let decision = (deny["hookSpecificOutput"] as? [String: Any])?["decision"] as? [String: Any]
        #expect(decision?["behavior"] as? String == "deny")
        let edit: [String: Any] = ["tool_name": "Edit", "tool_input": ["file_path": "/a/b/Notch.swift"]]
        #expect(ClaudeReplyRequest.permissionText(from: edit) == "Edit Notch.swift")
    }

    @Test func theReplyHookWaitsAndAlwaysSucceeds() {
        #expect(ClaudeQuestionHook.replyCommand.contains("reply=1"))
        #expect(ClaudeQuestionHook.replyCommand.hasSuffix("exit 0"))
        #expect(ClaudeQuestionHook.sessionCommand.hasSuffix("exit 0"))
        #expect(ClaudeQuestionHook.hooks.filter { $0.timeout != nil }.count == 2)
    }

    private func event(_ name: String, _ id: String = "s1", folder: String = "/Users/x/Dynotch", at date: Date) -> ClaudeSessionEvent? {
        ClaudeSessionEvent(
            input: ["hook_event_name": name, "session_id": id, "cwd": folder, "prompt": "Fix the bug\nplease"],
            app: "com.microsoft.VSCode", date: date
        )
    }

    @Test func sessionsFollowTheirSteps() throws {
        let service = ClaudeSessionService()
        let start = Date()
        service.handle(try #require(event("SessionStart", at: start)))
        #expect(service.sessions.first?.state == .ready)
        #expect(service.sessions.first?.project == "Dynotch")
        service.handle(try #require(event("UserPromptSubmit", at: start)))
        #expect(service.sessions.first?.state == .working)
        #expect(service.sessions.first?.prompt == "Fix the bug please")
        service.asks(session: "s1", needsYou: false, at: start)
        #expect(service.sessions.first?.state == .asks)
        service.answered(session: "s1", at: start)
        #expect(service.sessions.first?.state == .working)
        service.handle(try #require(event("Stop", at: start)))
        #expect(service.sessions.first?.state == .finished)
        // Another session comes on top; ending one removes it.
        service.handle(try #require(event("UserPromptSubmit", "s2", folder: "/Users/x/Other", at: start)))
        #expect(service.sessions.map(\.id) == ["s2", "s1"])
        service.clearFinished()
        #expect(service.sessions.map(\.id) == ["s2"])
        service.handle(try #require(event("SessionEnd", "s2", at: start)))
        #expect(service.sessions.isEmpty)
    }

    @Test func quietSessionsAreForgotten() throws {
        let service = ClaudeSessionService()
        let old = Date(timeIntervalSinceNow: -ClaudeSessionService.forgetAfter - 60)
        service.handle(try #require(event("SessionStart", "old", at: old)))
        service.handle(try #require(event("SessionStart", "new", at: Date())))
        #expect(service.sessions.map(\.id) == ["new"])
        #expect(ClaudeSessionEvent(input: ["hook_event_name": "Stop"], app: nil, date: Date()) == nil)
    }
}

/// The test builds' lists (spec TL-1…TL-4).
@MainActor
struct TestPlanTests {
    /// A running test build has its list, every item names a log.
    @Test func testBuildsHaveAList() {
        if UpdateLogic.isTestBuild(AppInfo.version) { #expect(TestPlan.current != nil) }
        for (version, items) in TestPlan.plans {
            #expect(UpdateLogic.isTestBuild(version))
            #expect(Set(items.map(\.id)).count == items.count)
            #expect(items.allSatisfy { !$0.log.isEmpty && !$0.text.isEmpty })
        }
        #expect(TestPlan.plan(for: "1.8.0") == nil)
    }

    @Test func theReportHasTheBrokenItemsWithTheirLog() throws {
        let defaults = try #require(UserDefaults(suiteName: "TestPlanTests"))
        defaults.removePersistentDomain(forName: "TestPlanTests")
        let items = [
            TestPlanItem(id: "a", group: "One", text: "First", log: "alpha"),
            TestPlanItem(id: "b", group: "Two", text: "Second", log: "beta"),
            TestPlanItem(id: "c", group: "One", text: "Third", log: "alpha")
        ]
        #expect(TestPlan.groups(items).map(\.name) == ["One", "Two"])
        let store = TestPlanStore(version: "9.9.1", items: items, defaults: defaults)
        store.set(.works, for: items[0])
        store.set(.broken, for: items[1])
        store.setNote("No buttons", for: items[1])
        let report = store.report { "log of \($0)" }
        #expect(report.contains("2 of 3 checked"))
        #expect(report.contains("✅ **One:** First"))
        #expect(report.contains("Note: No buttons"))
        #expect(report.contains("log of beta"))
        #expect(!report.contains("log of alpha"))
        // Kept per version.
        #expect(TestPlanStore(version: "9.9.1", items: items, defaults: defaults).statuses["b"] == .broken)
    }
}
