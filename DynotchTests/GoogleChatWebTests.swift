@testable import Dynotch
import Foundation
import Testing

/// Google Chat read from its web app (spec GW-1…GW-10).
struct GoogleChatWebTests {
    @Test func sidebarIdentifiersBecomeConversations() {
        #expect(GoogleChatWebReader.conversationID(fromDOM: "space/AAAAWDkvO2Q/SCcFR") == "space/AAAAWDkvO2Q")
        #expect(GoogleChatWebReader.conversationID(fromDOM: "dm/9N1_2cAAAAE/SCcFR") == "dm/9N1_2cAAAAE")
        #expect(GoogleChatWebReader.conversationID(fromDOM: "ucc-2") == nil)
        #expect(GoogleChatWebReader.conversationID(fromDOM: "space") == nil)
    }

    @Test func addressNamesTheOpenConversation() {
        #expect(GoogleChatWebReader.openID(fromPath: "/app/chat/AAAAWDkvO2Q") == "AAAAWDkvO2Q")
        #expect(GoogleChatWebReader.openID(fromPath: "/u/0/app/dm/9N1_2cAAAAE") == "9N1_2cAAAAE")
        #expect(GoogleChatWebReader.openID(fromPath: "/app/chat/AAAA/thread1") == "AAAA")
        #expect(GoogleChatWebReader.openID(fromPath: "/app/home") == nil)
    }

    @Test func unreadFromClassOrPreviewShortcut() {
        #expect(GoogleChatWebReader.isUnread(label: "x", classes: ["IL9EXe", "H7du2"]))
        #expect(GoogleChatWebReader.isUnread(label: "… az Option + 0 billentyűkombinációval …", classes: []))
        #expect(!GoogleChatWebReader.isUnread(label: "Beszélgetés", classes: ["rcdhB"]))
    }

    @Test func blankMessageBox() {
        #expect(GoogleChatWebReader.isBlank("\n"))
        #expect(GoogleChatWebReader.isBlank(" \u{200B}"))
        #expect(!GoogleChatWebReader.isBlank("hi"))
    }

    @Test func titleMatchesOneConversation() {
        let conversations = [
            ChatWebConversation(id: "dm/a", name: "Jane Doe", isUnread: true),
            ChatWebConversation(id: "space/b", name: "Support - Team", isUnread: false),
            ChatWebConversation(id: "space/c", name: "Design", isUnread: false),
            ChatWebConversation(id: "space/d", name: "Design Review", isUnread: false)
        ]
        #expect(GoogleChatWebService.match("Jane Doe", in: conversations)?.id == "dm/a")
        #expect(GoogleChatWebService.match("John Roe (Support - Team)", in: conversations)?.id == "space/b")
        #expect(GoogleChatWebService.match("jáne dóe", in: conversations)?.id == "dm/a")
        // Exact name wins over a longer one containing it.
        #expect(GoogleChatWebService.match("Design", in: conversations)?.id == "space/c")
        #expect(GoogleChatWebService.match("Nobody", in: conversations) == nil)
    }

    @Test func readOnlyOnceSeenUnreadOrAfterGrace() {
        let now = Date()
        let read = ChatWebConversation(id: "dm/a", name: "A", isUnread: false)
        let unread = ChatWebConversation(id: "dm/a", name: "A", isUnread: true)
        let fresh = now.addingTimeInterval(-10)
        #expect(!NotificationService.isRead(unread, notifiedAt: fresh, lastSeenUnread: now, now: now))
        #expect(NotificationService.isRead(read, notifiedAt: fresh, lastSeenUnread: now, now: now))
        // Not yet seen unread: the sidebar may still be catching up.
        #expect(!NotificationService.isRead(read, notifiedAt: fresh, lastSeenUnread: nil, now: now))
        #expect(NotificationService.isRead(read, notifiedAt: now.addingTimeInterval(-120), lastSeenUnread: nil, now: now))
    }
}
