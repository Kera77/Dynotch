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

    @Test func ownMessagesFromTheSenderHeading() {
        #expect(GoogleChatWebReader.isOwnHeading(name: "Ön", classes: ["ZTmjQb"]))
        #expect(GoogleChatWebReader.isOwnHeading(name: "", classes: ["ZTmjQb", "Z4BnXb", "cPjwNc"]))
        #expect(!GoogleChatWebReader.isOwnHeading(name: "Kiss Anna", classes: ["ZTmjQb", "Z4BnXb"]))
    }

    @Test func ownLinesAreMarkedInTheCardText() {
        let content = NotificationContent(sender: "A", detail: "", lines: [
            ChatWebMessage(id: "1", text: "hi"), ChatWebMessage(id: "2", text: "hello", isMine: true)
        ])
        #expect(content.lines.map(\.isMine) == [false, true])
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

    @Test func pinMarkerIsNotADirectMessageName() {
        let texts = ["Olvasatlan", "Nincs a gépnél", "Kiss Anna", "Kitűzött beszélgetés"]
        #expect(GoogleChatWebReader.nameAndCount(texts, isDirect: true).name == "Kiss Anna")
    }

    @Test func pinMarkerIsNotASpaceName() {
        let texts = ["Pinned", "Team space", "Space", "2 notifications"]
        let result = GoogleChatWebReader.nameAndCount(texts, isDirect: false)
        #expect(result.name == "Team space")
        #expect(result.count == 2)
    }

    @Test func pinMarkerIsNotAHomeRowName() {
        let preview = GoogleChatWebReader.homePreview(["Kiss Anna", "Kitűzve", "12:30", "Olvasatlan", "Kiss Anna: Szia"])
        #expect(preview?.name == "Kiss Anna")
        let pinnedFirst = GoogleChatWebReader.homePreview(["Kitűzött beszélgetés", "Kiss Anna", "12:30", "Kiss Anna: Szia"])
        #expect(pinnedFirst?.name == "Kiss Anna")
    }

    @Test func namesThatOnlyContainTheWordStay() {
        #expect(!GoogleChatWebReader.isPinMarker("Pinned items team"))
        #expect(GoogleChatWebReader.isPinMarker("Kitűzött beszélgetés"))
    }

    @Test func theNameSkipsTheUnreadMarkerAndTheStatus() {
        let texts = ["Olvasatlan", "Sales - Support", "Privát", "Kiemelt bejegyzés", "2 értesítés"]
        let space = GoogleChatWebReader.nameAndCount(texts, isDirect: false)
        #expect(space.name == "Sales - Support")
        #expect(space.count == 2)
        let readSpace = GoogleChatWebReader.nameAndCount(["Kereskedés Infó", "Beszélgetés"], isDirect: false)
        #expect(readSpace.name == "Kereskedés Infó")
        #expect(readSpace.count == nil)
        let direct = GoogleChatWebReader.nameAndCount(["Nincs a gépnél", "Olvasatlan", "Mark Smith", "1 értesítés"], isDirect: true)
        #expect(direct.name == "Mark Smith")
        #expect(direct.count == 1)
        #expect(GoogleChatWebReader.nameAndCount(["Anna Kovács"], isDirect: true).name == "Anna Kovács")
    }

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

    @Test func spaceNameComesFromTheParentheses() {
        #expect(GoogleChatJump.conversationName(from: "Krisztián Ivancsó (Support - Sysadmins)") == "Support - Sysadmins")
        #expect(GoogleChatJump.conversationName(from: "Kovács Anna") == "Kovács Anna")
        #expect(GoogleChatJump.conversationName(from: "Anna ()") == "Anna ()")
    }

    /// In a group each line shows who wrote it; in a direct message the title says it (spec GW-32).
    @Test func groupLinesNameTheirSender() {
        let line = ChatWebMessage(id: "1", text: "hi", sender: "Gergő")
        let group = NotificationContent(sender: "Csapat", detail: "hi", lines: [line])
        #expect(group.shownSender(of: line) == "Gergő")
        let direct = NotificationContent(sender: "Gergő", detail: "hi", lines: [line])
        #expect(direct.shownSender(of: line) == nil)
        #expect(group.shownSender(of: ChatWebMessage(id: "2", text: "x")) == nil)
    }
}
