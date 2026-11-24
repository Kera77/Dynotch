@testable import Dynotch
import Foundation
import Testing

/// Beeper: answering a line, read chats, its networks and the wide tab.
@MainActor
struct BeeperTests {
    private func makeModel() -> NotchViewModel {
        let name = "BeeperTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        return NotchViewModel(settings: AppSettings(defaults: defaults), geometry: geometry, screenName: "Test")
    }

    @Test func theAnsweredLineIsFoundAmongBeepersMessages() {
        let messages = [
            BeeperMessage(id: "1", text: "See you tomorrow", timestamp: "1"),
            BeeperMessage(id: "2", text: "Can you send the report today please?", timestamp: "2"),
            BeeperMessage(id: "3", text: "See you tomorrow", timestamp: "3")
        ]
        #expect(BeeperClient.message(matching: "see you tomorrow", in: messages)?.id == "3")
        // A notification may shorten a long message.
        #expect(BeeperClient.message(matching: "Can you send the report", in: messages)?.id == "2")
        #expect(BeeperClient.message(matching: "Something else", in: messages) == nil)
        #expect(BeeperClient.message(matching: " ", in: messages) == nil)
    }

    @Test func beeperMessageGoesOnceItsChatIsRead() throws {
        let json = #"[{"id":"1","title":"Anna","unreadCount":0},{"id":"2","title":"Béla","unreadCount":2}]"#
        let chats = try JSONDecoder().decode([BeeperChatInfo].self, from: Data(json.utf8))
        #expect(ChatSources.isRead(chatNamed: "anna ", in: chats))
        #expect(!ChatSources.isRead(chatNamed: "Béla", in: chats))
        // A name Beeper does not know stays in the list.
        #expect(!ChatSources.isRead(chatNamed: "Cecil", in: chats))
    }

    @Test func accountNetworksDecodeFromArrayOrItems() {
        let array = Data(#"[{"accountID":"a","network":"Telegram"},{"accountID":"b","network":"Google Chat"},{"network":"Telegram"}]"#.utf8)
        #expect(BeeperAccounts.networks(from: array) == ["Telegram", "Google Chat"])
        let page = Data(#"{"items":[{"network":"Signal"}]}"#.utf8)
        #expect(BeeperAccounts.networks(from: page) == ["Signal"])
    }

    @Test func networksMergeWithTheChatsSpelling() {
        let merged = BeeperAccounts.merged(chats: ["Google Chat", "WhatsApp"], accounts: ["googlechat", "Telegram"], highlighted: [])
        #expect(merged == ["Google Chat", "Telegram", "WhatsApp"])
    }

    @Test func beeperTabIsWideOnlyWithItsList() {
        let model = makeModel()
        model.setExpanded(true)
        model.select(.notifications)
        model.notificationsTab = .beeper
        model.beeperListOpen = true
        #expect(model.openSize == model.geometry.chatPanelSize)
        model.beeperListOpen = false
        #expect(model.openSize != model.geometry.chatPanelSize)
        model.notificationsTab = .googleChat
        let googleChat = model.openSize
        model.notificationsTab = .beeper
        #expect(model.openSize == googleChat)
    }
}
