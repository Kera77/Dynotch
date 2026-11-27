import Foundation
import Testing
@testable import Wingmate

/// Reading the web Teams (spec MT-1…MT-6).
struct TeamsTests {
    @Test func domIDsMarkTheChatListAndTheMessages() {
        #expect(TeamsPage.part(ofDOM: "title-chat-list-item_19:abc@thread.v2") == .title("19:abc@thread.v2"))
        #expect(TeamsPage.part(ofDOM: "message-preview-chat-list-item_48:notes") == .preview("48:notes"))
        #expect(TeamsPage.part(ofDOM: "time-chat-list-item_48:notes") == .time("48:notes"))
        #expect(TeamsPage.part(ofDOM: "chat-header-19:abc@thread.v2") == .header("19:abc@thread.v2"))
        #expect(TeamsPage.part(ofDOM: "chat-header-find-in-chat-search") == nil)
        #expect(TeamsPage.part(ofDOM: "author-1795698837291") == .author("1795698837291"))
        #expect(TeamsPage.part(ofDOM: "message-body-1795698837291") == .body("1795698837291"))
        #expect(TeamsPage.part(ofDOM: "content-1795698837291") == .content("1795698837291"))
        #expect(TeamsPage.part(ofDOM: "content-abc") == nil)
    }

    @Test func windowsAndHosts() {
        #expect(TeamsPage.isTeamsWindow(title: "Loginet2 — teams.live.com"))
        #expect(TeamsPage.isTeamsWindow(title: "Chat | Anna | Microsoft Teams"))
        #expect(!TeamsPage.isTeamsWindow(title: "Loginet2 — chat.google.com"))
        #expect(TeamsPage.isTeamsHost("teams.live.com"))
        #expect(TeamsPage.isTeamsHost("teams.cloud.microsoft"))
        #expect(!TeamsPage.isTeamsHost("live.com"))
    }

    @Test func unreadAndMentionsComeFromTheRowLabel() {
        let label = "Unread message One on one chat Anna Hello 10:24"
        #expect(TeamsPage.isUnread(label: label))
        #expect(!TeamsPage.isUnread(label: "One on one chat Anna Hello 10:24"))
        #expect(TeamsPage.isMention(label: "Personal at mention Unread message Group"))
        var snapshot = TeamsSnapshot()
        snapshot.chats = [
            TeamsChat(id: "a", name: "A", isUnread: true),
            TeamsChat(id: "b", name: "B"),
            TeamsChat(id: "c", name: "C", isUnread: true, isMention: true)
        ]
        #expect(snapshot.unread.map(\.id) == ["c", "a"])
    }

    @Test func meetingControls() {
        #expect(TeamsPage.control(domID: "hangup-button", label: "Leave") == .leave)
        #expect(TeamsPage.control(domID: "", label: "Unmute (⌘+Shift+M)") == .mic)
        #expect(TeamsPage.control(domID: "", label: "Turn camera on") == .camera)
        #expect(TeamsPage.control(domID: "", label: "Video call") == nil)
        #expect(TeamsPage.control(domID: "", label: "Raise") == .hand)
        #expect(TeamsPage.control(domID: "", label: "Send") == nil)
        #expect(TeamsPage.isMuted(label: "Unmute (⌘+Shift+M)", toggleValue: nil) == true)
        #expect(TeamsPage.isMuted(label: "Mute (⌘+Shift+M)", toggleValue: nil) == false)
        #expect(TeamsPage.isMuted(label: "Mic", toggleValue: 1) == false)
        #expect(TeamsPage.isCameraOn(label: "Turn camera off", toggleValue: nil) == true)
        #expect(TeamsPage.meetingTitle(fromPageTitle: "Weekly sync | Microsoft Teams") == "Weekly sync")
        #expect(TeamsPage.meetingTitle(fromPageTitle: "Microsoft Teams") == "Teams meeting")
    }

    @MainActor @Test func theMeetingSitsBesideTheNotch() {
        let meeting = TeamsMeeting(title: "Sync", isMuted: true, controls: [.mic, .leave])
        let items = IndicatorItem.items(meetings: [], usage: nil, teams: (meeting, Date()))
        #expect(items.map(\.id) == ["teams"])
        #expect(items[0].slotWidth > 0)
        #expect(NotchController.pinchFeature(of: items[0]) == .notifications)
        #expect(NotificationsTab.shown(mail: false, teams: true).contains(.teams))
        #expect(!NotificationsTab.shown(mail: false).contains(.teams))
    }
}
