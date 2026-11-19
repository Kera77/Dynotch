@testable import Dynotch
import Foundation
import Testing

/// The web conversations beside the AI chats (spec AI-17).
struct WebAIHistoryTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func claudeAndChatGPTConversationsAreRecognised() throws {
        let claude = try #require(
            WebAIHistory.conversation(url: "https://claude.ai/chat/abc?x=1", title: "Plan a trip - Claude", visited: now)
        )
        #expect(claude.provider == .claude)
        #expect(claude.title == "Plan a trip")
        #expect(claude.url.absoluteString == "https://claude.ai/chat/abc")
        let chatGPT = try #require(WebAIHistory.conversation(url: "https://chatgpt.com/c/123", title: "Kazán beállítása", visited: now))
        #expect(chatGPT.provider == .chatgpt)
    }

    @Test func otherPagesAndUntitledOnesAreLeftOut() {
        #expect(WebAIHistory.conversation(url: "https://claude.ai/new", title: "Claude", visited: now) == nil)
        #expect(WebAIHistory.conversation(url: "https://chatgpt.com/c/456", title: "New chat", visited: now) == nil)
        #expect(WebAIHistory.conversation(url: "https://chatgpt.com/c/local-1", title: "Draft", visited: now) == nil)
        #expect(WebAIHistory.conversation(url: "https://example.com/c/1", title: "Hello", visited: now) == nil)
    }

    @Test func eachConversationOnceWithItsNewestVisit() throws {
        let old = try #require(WebAIHistory.conversation(url: "https://chatgpt.com/c/1", title: "Old title", visited: now))
        let later = now.addingTimeInterval(60)
        let new = try #require(WebAIHistory.conversation(url: "https://chatgpt.com/c/1", title: "New title", visited: later))
        let between = now.addingTimeInterval(30)
        let other = try #require(WebAIHistory.conversation(url: "https://claude.ai/chat/2", title: "Other", visited: between))
        let merged = WebAIHistory.merged([old, other, new])
        #expect(merged.map(\.title) == ["New title", "Other"])
    }
}
