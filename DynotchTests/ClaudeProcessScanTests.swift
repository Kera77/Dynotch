@testable import Dynotch
import Foundation
import Testing

/// Sessions found as running processes, in every app (spec CS-9).
@MainActor
struct ClaudeProcessScanTests {
    private func found(_ pid: pid_t, app: String?, folder: String = "/Users/x/Dynotch") -> ClaudeProcessScan.Found {
        ClaudeProcessScan.Found(pid: pid, app: app, folder: folder, started: Date(timeIntervalSince1970: TimeInterval(pid)))
    }

    @Test func everyAppsSessionIsListed() throws {
        let service = ClaudeSessionService()
        service.popupEnabled = { true }
        let vscode = try #require(ClaudeSessionEvent(
            input: ["hook_event_name": "UserPromptSubmit", "session_id": "s1", "cwd": "/Users/x/Dynotch"],
            app: "com.microsoft.VSCode", date: Date()
        ))
        service.handle(vscode)
        service.closePopup()
        // The VS Code process is the hooked row; the Claude app's has no hook event yet.
        service.merge([found(10, app: "com.microsoft.VSCode"), found(20, app: "com.anthropic.claudefordesktop")])
        #expect(service.sessions.map(\.id) == ["s1", "pid:20"])
        #expect(service.sessions.last?.state == .ready)
        #expect(service.sessions.last?.app == "com.anthropic.claudefordesktop")
        // Its first hook event takes the found row's place, without a "new session" pop-up.
        service.handle(try #require(ClaudeSessionEvent(
            input: ["hook_event_name": "UserPromptSubmit", "session_id": "s2", "cwd": "/Users/x/Dynotch"],
            app: "com.anthropic.claudefordesktop", date: Date()
        )))
        #expect(service.sessions.map(\.id) == ["s2", "s1"])
        #expect(!service.popupShown)
    }

    @Test func endedOrRemovedProcessesGo() {
        let service = ClaudeSessionService()
        service.merge([found(30, app: "com.apple.Terminal"), found(31, app: nil, folder: "/Users/x/Other")])
        #expect(service.sessions.map(\.id) == ["pid:30", "pid:31"])
        service.remove("pid:30")
        service.merge([found(30, app: "com.apple.Terminal")])
        #expect(service.sessions.isEmpty)
    }

    @Test func helpersCountAsTheirApp() {
        #expect(ClaudeProcessScan.hostBundleID("com.anthropic.claude-code") == "com.anthropic.claudefordesktop")
        #expect(ClaudeProcessScan.hostBundleID("com.anthropic.claudefordesktop.helper.Plugin") == "com.anthropic.claudefordesktop")
        #expect(ClaudeProcessScan.hostBundleID("com.microsoft.VSCode.helper") == "com.microsoft.VSCode")
        #expect(ClaudeProcessScan.hostBundleID("com.apple.Terminal") == "com.apple.Terminal")
        let helper = "/Applications/Claude.app/Contents/Frameworks/Claude Helper (Plugin).app/Contents/MacOS/Claude Helper (Plugin)"
        #expect(ClaudeProcessScan.outermostApp(in: helper) == "/Applications/Claude.app")
        #expect(ClaudeProcessScan.outermostApp(in: "/bin/zsh") == nil)
        #expect(ClaudeProcessScan.isClaude(path: "/Users/x/.local/share/claude/versions/2.1.173"))
        let builtIn = "/Users/x/Library/Application Support/Claude/claude-code/2.1/h/claude.app/Contents/MacOS/claude"
        #expect(ClaudeProcessScan.isClaude(path: builtIn))
        #expect(!ClaudeProcessScan.isClaude(path: "/Applications/Claude.app/Contents/MacOS/Claude"))
    }
}
