import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// Behaviours added in 0.25.
@MainActor
struct V025Tests {
    private func makeDefaults() -> UserDefaults {
        let name = "V025Tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - Claude finished only when everything is done (spec CN-3)

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

    // MARK: - Claude Code history (spec CC-6)

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

    @Test func aClaudeCodeSessionIsTakenOverAsAChat() {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("chats-\(UUID().uuidString).json")
        let service = ClaudeChatService(file: file, defaults: makeDefaults())
        let session = ClaudeCodeSession(
            id: "sess-1", title: "Old work", workingDirectory: "/tmp", file: file, modified: Date(timeIntervalSince1970: 1_700_000_000)
        )
        service.setCodeSessions([session])
        #expect(service.codeSessions == [session])

        service.open(session)
        #expect(service.codeSessions.isEmpty)
        let chat = service.selected
        #expect(chat?.title == "Old work")
        #expect(chat?.sessionID == "sess-1")
        #expect(chat?.needsFork == true)
        if let id = chat?.id {
            service.setImportedMessages([ChatMessage(role: .user, text: "hello")], for: id)
            #expect(service.selected?.messages.count == 1)
            // The first answer continues a copy: its new session replaces the old one.
            _ = service.begin("more")
            service.finish(id, text: "ok", sessionID: "sess-2", isError: false)
            #expect(service.selected?.sessionID == "sess-2")
            #expect(service.selected?.needsFork == nil)
        }
        // Already taken over: not offered again.
        service.setCodeSessions([session])
        #expect(service.codeSessions.isEmpty)
        #expect(ClaudeCLI.arguments(prompt: "x", sessionID: "s", fork: true).suffix(3) == ["--resume", "s", "--fork-session"])
    }

    @Test func theSidebarStateIsRememberedAndBothPanelsCountAsVisible() {
        let defaults = makeDefaults()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("chats-\(UUID().uuidString).json")
        let service = ClaudeChatService(file: file, defaults: defaults)
        #expect(service.showsSidebar)
        service.showsSidebar = false
        #expect(!ClaudeChatService(file: file, defaults: defaults).showsSidebar)

        var announced = 0
        service.onAnswerReady = { _ in announced += 1 }
        service.isVisibleInMenuBar = true
        service.finish(service.begin("a"), text: "x", sessionID: nil, isError: false)
        #expect(announced == 0)
        service.isVisibleInMenuBar = false
        service.finish(service.begin("b"), text: "y", sessionID: nil, isError: false)
        #expect(announced == 1)
    }

    // MARK: - Focus (spec F-8)

    @Test func focusNeverMovesInsideTheActiveApp() {
        #expect(!FocusRules.shouldSwitch(targetPID: 10, frontPID: 10))
        #expect(FocusRules.shouldSwitch(targetPID: 11, frontPID: 10))
        #expect(FocusRules.shouldSwitch(targetPID: 11, frontPID: nil))
    }

    // MARK: - Preview on hover (spec PV-1…PV-3)

    @Test func thePreviewIsSmallAndGivesWayToTheFullPanel() {
        let settings = AppSettings(defaults: makeDefaults())
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663, auxiliaryRightWidth: 664, menuBarHeight: 32
        )
        let model = NotchViewModel(settings: settings, geometry: geometry, screenName: "Test")
        model.setPreview(true)
        #expect(!model.isPreview)

        model.setExpanded(true)
        model.setPreview(true)
        #expect(model.isPreview)
        #expect(model.openSize == geometry.previewSize)
        #expect(geometry.previewSize.height < geometry.expandedSize.height)
        #expect(!model.wantsKeyboard)

        model.select(.calculator)
        #expect(!model.isPreview)
        #expect(model.openSize == geometry.expandedSize)

        model.setPreview(true)
        model.setExpanded(false)
        #expect(!model.isPreview)
    }

    @Test func previewSettings() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        #expect(!settings.hoverPreview)
        #expect(settings.previewDelay == 1.5)
        #expect(settings.previewOpensOnClick)
        settings.hoverPreview = true
        settings.previewDelay = 9
        settings.previewOpensOnClick = false
        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.hoverPreview)
        #expect(reloaded.previewDelay == 5)
        #expect(!reloaded.previewOpensOnClick)
        #expect(AppSettings.menuBarFeatures.contains(.claudeChat))

        #expect(FeaturePreview.line(of: "\n  first \nsecond", fallback: "-") == "first")
        #expect(FeaturePreview.line(of: "1+1\n= 2\n", fallback: "-", last: true) == "= 2")
        #expect(FeaturePreview.line(of: " \n", fallback: "Empty") == "Empty")
        #expect(FeaturePreview.line(of: String(repeating: "a", count: 90), fallback: "-").count == 71)
    }
}
