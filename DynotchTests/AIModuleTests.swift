@testable import Dynotch
import Foundation
import Testing

/// The AI module: Claude and ChatGPT (spec AI-1…AI-12).
struct AIModuleTests {
    @Test func codexLinesBecomeChatEvents() {
        #expect(CodexStream.event(fromLine: #"{"type":"thread.started","thread_id":"t1"}"#) == .session("t1"))
        #expect(CodexStream.event(fromLine: #"{"type":"item.completed","item":{"type":"agent_message","text":"Hi"}}"#) == .replace("Hi"))
        #expect(CodexStream.event(fromLine: #"{"type":"item.completed","item":{"type":"reasoning","text":"…"}}"#) == nil)
        #expect(CodexStream.event(fromLine: #"{"type":"turn.completed"}"#) == .result(text: "", sessionID: nil, isError: false))
        let failed = CodexStream.event(fromLine: #"{"type":"turn.failed","error":{"message":"Not signed in"}}"#)
        #expect(failed == .result(text: "Not signed in", sessionID: nil, isError: true))
    }

    @Test func chatGPTLimitsFromTheLog() throws {
        let line = """
        {"type":"event_msg","payload":{"rate_limits":{"primary":{"used_percent":42.0,"window_minutes":300,"resets_at":1800000000},\
        "secondary":{"used_percent":6.0,"window_minutes":10080,"resets_at":1800500000}}}}
        """
        let limits = try #require(CodexUsage.limits(fromLine: line))
        #expect(limits.map(\.title) == ["ChatGPT · 5 hours", "ChatGPT · week"])
        #expect(abs(limits[0].utilization - 42) < 0.001)
        #expect(limits[0].resetsAt == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(CodexUsage.title(minutes: 43_200) == "30 days")
    }

    @Test func theAccountsModelsFromCodexsList() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("models-\(UUID().uuidString).json")
        let json = """
        {"models":[{"slug":"gpt-a","display_name":"GPT-A","visibility":"list"},{"slug":"hidden","visibility":"hide"}]}
        """
        try Data(json.utf8).write(to: file)
        #expect(CodexCLI.models(in: file) == [AIModel(id: "gpt-a", title: "GPT-A")])
        #expect(AIProvider.claude.models().map(\.id) == ["opus", "sonnet", "haiku"])
    }

    @Test func codexRunsReadOnlyAndResumes() {
        let arguments = CodexCLI.arguments(
            prompt: "Hi", threadID: "t1", model: "gpt-a", thinksHarder: true, images: [URL(fileURLWithPath: "/tmp/a.png")]
        )
        #expect(arguments.prefix(3) == ["exec", "resume", "t1"])
        #expect(arguments.contains("--json") && arguments.contains("read-only") && arguments.last == "Hi")
        #expect(arguments.contains("model_reasoning_effort=\"high\""))
        #expect(ClaudeCLI.arguments(prompt: "Hi", sessionID: nil, model: "sonnet", canRead: true).contains("Read"))
    }

    @Test func answersAndAttachments() {
        #expect(AIPrompt.withFiles("Q", []) == "Q")
        #expect(AIPrompt.withFiles("Q", [URL(fileURLWithPath: "/x/a.pdf")]).hasSuffix("- /x/a.pdf"))
        let heading = String(AIMessageContent.formatted("# Title\ntext").characters)
        #expect(heading == "Title\ntext")
    }

    @Test @MainActor func pinnedChatsComeFirstAndSearchFinds() {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("chats-\(UUID().uuidString).json")
        let name = "AIModuleTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let service = ClaudeChatService(file: file, defaults: defaults)
        let first = service.begin("First question")
        service.newChat()
        _ = service.begin("Second about apples")
        service.togglePin(first)
        #expect(service.listedChats(matching: "").first?.id == first)
        #expect(service.listedChats(matching: "apples").count == 1)
        #expect(service.chats.first { $0.id == first }?.provider == .claude)
    }
}
