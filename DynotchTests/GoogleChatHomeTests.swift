@testable import Dynotch
import Foundation
import Testing

/// The Google Chat web app's Home list: last message, sender, count (spec GW-21…GW-23).
struct GoogleChatHomeTests {
    private let hint = "A Tab billentyűvel további lehetőségeket jeleníthet meg."

    @Test func readsAGroupRow() throws {
        let preview = try #require(GoogleChatWebReader.homePreview(
            ["Gergely, Gergő", "43 perc", "Olvasatlan", "Gergő Karádi: Mindkettő jó", hint, "1 értesítés"]
        ))
        #expect(preview.name == "Gergely, Gergő")
        #expect(preview.time == "43 perc")
        #expect(preview.sender == "Gergő Karádi")
        #expect(preview.text == "Mindkettő jó")
        #expect(preview.isUnread)
        #expect(preview.count == 1)
    }

    @Test func readsADirectAndAnOwnRow() throws {
        let direct = try #require(GoogleChatWebReader.homePreview(["Nincs a gépnél", "Levente Támpa", "18 perc", "köszi!", hint]))
        #expect(direct.name == "Levente Támpa")
        #expect(direct.sender == nil)
        #expect(direct.text == "köszi!")
        #expect(!direct.isUnread)
        let own = try #require(GoogleChatWebReader.homePreview(["Bence Katona", "12:30", "Ön: rendben, holnap: 10-kor", hint]))
        #expect(own.isMine)
        #expect(own.text == "rendben, holnap: 10-kor")
    }

    /// An old space keeps "1 értesítés" after it was read: without "Olvasatlan" it is read (spec GW-26).
    @Test func countAloneIsNotUnread() throws {
        let preview = try #require(GoogleChatWebReader.homePreview(["StickyPrompts Support", "Cs", "Anna: kész", hint, "1 értesítés"]))
        #expect(!preview.isUnread)
        #expect(preview.count == nil)
        let sidebar = [ChatWebConversation(id: "space/S", name: "StickyPrompts Support", isUnread: false)]
        let merged = GoogleChatWebReader.merge([(id: "space/S", preview: preview)], into: sidebar)
        #expect(!merged[0].isUnread)
        #expect(ChatWebSnapshot(conversations: merged).unreadTotal == 0)
    }

    @Test func rejectsRowsWithoutTimeOrMessage() {
        #expect(GoogleChatWebReader.homePreview(["Krisztián, István", "Beszélgetés", "Kitűzött beszélgetés"]) == nil)
        #expect(GoogleChatWebReader.homePreview(["Anna", "4 perc", hint]) == nil)
    }

    @Test func recognizesTimes() {
        for text in ["4 perc", "2 óra", "12:30", "Tegnap", "H", "Sze", "nov. 20.", "3:05 PM", "Nov 20"] {
            #expect(GoogleChatWebReader.isTime(text), "\(text)")
        }
        for text in ["Anna", "Eatrend support átvétel - okt. 13.", "1 értesítés"] {
            #expect(!GoogleChatWebReader.isTime(text), "\(text)")
        }
    }

    @Test func mergesPreviewsByIDOrName() {
        let sidebar = [
            ChatWebConversation(id: "space/A", name: "Gergely, Gergő", isUnread: false),
            ChatWebConversation(id: "dm/B", name: "Levente Támpa", isUnread: true, unreadCount: 1)
        ]
        let group = ChatWebPreview(name: "Gergely, Gergő", time: "1 perc", sender: "Gergő", text: "jó", isUnread: true, count: 2)
        let direct = ChatWebPreview(name: "Levente Támpa", time: "2 perc", sender: nil, text: "szia", count: 3)
        let merged = GoogleChatWebReader.merge([("space/A", group), (nil, direct)], into: sidebar)
        #expect(merged[0].isUnread && merged[0].unreadCount == 2 && merged[0].preview == group)
        #expect(merged[1].unreadCount == 3 && merged[1].preview == direct)
        var snapshot = ChatWebSnapshot()
        snapshot.conversations = merged
        #expect(snapshot.unreadTotal == 5)
    }

    @Test func cardTextNamesTheSender() {
        var conversation = ChatWebConversation(id: "space/A", name: "Team", isUnread: true, unreadCount: 2)
        #expect(NotificationService.cardText(conversation) == "2 unread messages in Google Chat")
        conversation.preview = ChatWebPreview(name: "Team", time: "1 perc", sender: "Anna", text: "Kész")
        #expect(NotificationService.cardText(conversation) == "Anna: Kész")
        conversation.preview = ChatWebPreview(name: "Team", time: "1 perc", sender: "Ön", text: "Ok", isMine: true)
        #expect(NotificationService.cardText(conversation) == "You: Ok")
    }

    @Test func turnsTimesIntoDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Budapest"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 14)))
        #expect(ChatWebTime.date(from: "4 perc", now: now, calendar: calendar) == now.addingTimeInterval(-240))
        #expect(ChatWebTime.date(from: "2 óra", now: now, calendar: calendar) == now.addingTimeInterval(-7200))
        #expect(ChatWebTime.date(from: "12:30", now: now, calendar: calendar) == now.addingTimeInterval(-5400))
        #expect(ChatWebTime.date(from: "15:00", now: now, calendar: calendar) == now.addingTimeInterval(-82_800))
        #expect(ChatWebTime.date(from: "nov. 20.", now: now, calendar: calendar) == nil)
    }
}
