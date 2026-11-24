@testable import Dynotch
import Foundation
import Testing

@MainActor
struct ClaudeChatTests {
    private func makeService() -> ClaudeChatService {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("chats-\(UUID().uuidString).json")
        return ClaudeChatService(file: file)
    }

    @Test func streamLinesAreRead() {
        let delta = #"{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"hel"}}}"#
        #expect(ClaudeStream.event(fromLine: delta) == .delta("hel"))
        let result = #"{"type":"result","subtype":"success","is_error":false,"result":"hello","session_id":"abc"}"#
        #expect(ClaudeStream.event(fromLine: result) == .result(text: "hello", sessionID: "abc", isError: false))
        #expect(ClaudeStream.event(fromLine: #"{"type":"system","subtype":"init"}"#) == nil)
        #expect(ClaudeStream.event(fromLine: #"{"type":"stream_event","event":{"type":"message_stop"}}"#) == nil)
        #expect(ClaudeStream.event(fromLine: "not json") == nil)
    }

    @Test func theNewestBundledProgramIsUsed() {
        let paths = [
            "/x/anthropic.claude-code-2.1.99-darwin-arm64/resources/native-binary/claude",
            "/x/anthropic.claude-code-2.1.325-darwin-arm64/resources/native-binary/claude",
            "/x/anthropic.claude-code-2.0.400-darwin-arm64/resources/native-binary/claude"
        ]
        #expect(ClaudeCLI.newest(of: paths) == paths[1])
        #expect(ClaudeCLI.newest(of: []) == nil)
        #expect(ClaudeCLI.arguments(prompt: "hi", sessionID: "s1").suffix(2) == ["--resume", "s1"])
        #expect(!ClaudeCLI.arguments(prompt: "hi", sessionID: nil).contains("--resume"))
    }

    /// Spec CC-1…CC-3: a question starts a chat, the answer streams in, the session is kept.
    @Test func aQuestionStartsAChatAndTheAnswerStreamsIn() {
        let service = makeService()
        #expect(!service.isTall)
        let id = service.begin("What is a notch?\nMore detail")
        #expect(service.selected?.title == "What is a notch?")
        #expect(service.isWorking)
        #expect(service.isTall)

        service.apply(.delta("A cut"), to: id)
        service.apply(.delta("out."), to: id)
        #expect(service.selected?.messages.last?.text == "A cutout.")
        service.apply(.result(text: "A cutout.", sessionID: "s1", isError: false), to: id)
        #expect(!service.isWorking)
        #expect(service.selected?.sessionID == "s1")
        #expect(service.selected?.messages.map(\.role) == [.user, .assistant])

        // The next question goes into the same chat.
        _ = service.begin("And why?")
        #expect(service.chats.count == 1)
        #expect(service.selected?.messages.count == 4)
    }

    @Test func errorsReplaceTheAnswerAndKeepTheSession() {
        let service = makeService()
        let id = service.begin("hi")
        service.apply(.result(text: "ok", sessionID: "s1", isError: false), to: id)
        _ = service.begin("again")
        service.apply(.delta("par"), to: id)
        service.apply(.result(text: "API Error", sessionID: "other", isError: true), to: id)
        #expect(service.selected?.messages.last?.text == "API Error")
        #expect(service.selected?.messages.last?.isError == true)
        #expect(service.selected?.sessionID == "s1")
    }

    /// Spec CC-5: an answer that arrives while the chat is not on screen is announced.
    @Test func anAnswerIsAnnouncedOnlyWhenTheChatIsHidden() {
        let service = makeService()
        var announced: [String] = []
        service.onAnswerReady = { announced.append($0.title) }

        service.isVisible = true
        var id = service.begin("seen")
        service.finish(id, text: "a", sessionID: nil, isError: false)
        #expect(announced.isEmpty)

        service.isVisible = false
        service.newChat()
        id = service.begin("hidden")
        service.finish(id, text: "b", sessionID: nil, isError: false)
        #expect(announced == ["hidden"])
        #expect(service.chats.map(\.title) == ["hidden", "seen"])
    }

    @Test func chatsArePersistedAndDeleted() {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("chats-\(UUID().uuidString).json")
        let service = ClaudeChatService(file: file)
        let id = service.begin("keep me")
        service.finish(id, text: "ok", sessionID: "s", isError: false)

        let reloaded = ClaudeChatService(file: file)
        #expect(reloaded.chats.first?.title == "keep me")
        #expect(reloaded.chats.first?.messages.last?.text == "ok")
        reloaded.delete(id)
        #expect(ClaudeChatService(file: file).chats.isEmpty)
    }

    /// Spec CC-4: the working dots share the Claude icon with the usage ring.
    @Test func workingIsShownBesideTheNotch() {
        let items = IndicatorItem.items(meetings: [], usage: nil, working: true)
        #expect(items == [.working])
        #expect(IndicatorItem.iconSlots(for: items) == [0])
        let limit = UsageLimit(id: "five_hour", title: "Session", utilization: 80, resetsAt: nil)
        let both = IndicatorItem.items(meetings: [], usage: [limit], working: true)
        #expect(IndicatorItem.iconSlots(for: both) == [0])
        #expect(IndicatorItem.items(meetings: [], usage: nil).isEmpty)
    }

    @Test func dynotchsOwnRunsAreNotAnnouncedByTheHook() throws {
        let own = try #require(URL(string: "dynotch://claude-finished?project=\(ClaudeCLI.folderName)"))
        #expect(ClaudeHook.notice(from: own, now: Date()) == nil)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "ClaudeChatTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest") ?? .current
        return calendar
    }

    /// 2026-11-18 10:00 Budapest
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10)) ?? Date()
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

    @Test func favoritesNewestFirst() {
        var older = ChatMessage(role: .assistant, text: "old", date: now.addingTimeInterval(-60))
        older.isFavorite = true
        var newer = ChatMessage(role: .assistant, text: "new", date: now)
        newer.isFavorite = true
        let plain = ChatMessage(role: .assistant, text: "plain", date: now)
        let chat = ClaudeChat(title: "C", messages: [older, plain, newer])
        let favorites = ClaudeChatService.favorites(in: [chat])
        #expect(favorites.map(\.message.text) == ["new", "old"])
    }
}
