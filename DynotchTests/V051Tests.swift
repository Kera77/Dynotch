@testable import Dynotch
import Foundation
import Testing

/// Google Chat replies by name, Beeper messages read elsewhere.
struct V051Tests {
    @Test func googleChatNameIsConfirmedInTitleOrField() {
        #expect(GoogleChatJump.matches("Kovács Anna", in: ["Kovacs Anna - Chat"]))
        #expect(GoogleChatJump.matches("Kovács Anna", in: ["Message Anna Kovács"]))
        #expect(GoogleChatJump.matches("Team Loginet", in: ["team loginet"]))
        // Another chat, or nothing shown: never confirmed.
        #expect(!GoogleChatJump.matches("Kovács Anna", in: ["Kiss Béla - Chat"]))
        #expect(!GoogleChatJump.matches("Kovács Anna", in: ["Anna"]))
        #expect(!GoogleChatJump.matches("Kovács Anna", in: []))
        #expect(!GoogleChatJump.matches(" ", in: ["anything"]))
    }

    @Test func beeperMessageGoesOnceItsChatIsRead() throws {
        let json = #"[{"id":"1","title":"Anna","unreadCount":0},{"id":"2","title":"Béla","unreadCount":2}]"#
        let chats = try JSONDecoder().decode([BeeperChatInfo].self, from: Data(json.utf8))
        #expect(ChatSources.isRead(chatNamed: "anna ", in: chats))
        #expect(!ChatSources.isRead(chatNamed: "Béla", in: chats))
        // A name Beeper does not know stays in the list.
        #expect(!ChatSources.isRead(chatNamed: "Cecil", in: chats))
    }

    @Test func shrinkingIsTellingNarrowerOrLower() {
        let wide = CGRect(x: 0, y: 0, width: 760, height: 420)
        #expect(NotchController.shrank(from: wide, to: CGRect(x: 100, y: 0, width: 560, height: 420)))
        #expect(NotchController.shrank(from: wide, to: CGRect(x: 0, y: 100, width: 760, height: 320)))
        #expect(!NotchController.shrank(from: wide, to: wide))
        #expect(!NotchController.shrank(from: wide, to: CGRect(x: 0, y: 0, width: 800, height: 500)))
    }

    @Test func spaceNameComesFromTheParentheses() {
        #expect(GoogleChatJump.conversationName(from: "Krisztián Ivancsó (Support - Sysadmins)") == "Support - Sysadmins")
        #expect(GoogleChatJump.conversationName(from: "Kovács Anna") == "Kovács Anna")
        #expect(GoogleChatJump.conversationName(from: "Anna ()") == "Anna ()")
    }
}
