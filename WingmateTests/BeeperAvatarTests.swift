import Foundation
import Testing
@testable import Wingmate

struct BeeperAvatarTests {
    @Test func monogramFromTwoWords() {
        #expect(BeeperAvatar.initials(of: "Kovács Anna") == "KA")
        #expect(BeeperAvatar.initials(of: "anna") == "A")
        #expect(BeeperAvatar.initials(of: "Anna Bea Cili") == "AB")
    }

    @Test func monogramSkipsEmojiAndNumbers() {
        #expect(BeeperAvatar.initials(of: "🎉 Buli csapat") == "BC")
        #expect(BeeperAvatar.initials(of: "+36 30 123 4567") == "3")
        #expect(BeeperAvatar.initials(of: "  ") == "?")
    }

    @Test func oneToOneChatUsesTheOtherPersonsPicture() throws {
        let json = """
        {"id":"1","type":"single","participants":{"items":[
          {"id":"me","isSelf":true,"imgURL":"file:///me.jpg"},
          {"id":"you","isSelf":false,"imgURL":"file:///you.jpg"}]}}
        """
        let chat = try JSONDecoder().decode(BeeperChatInfo.self, from: Data(json.utf8))
        #expect(chat.pictureURL == "file:///you.jpg")
    }

    @Test func groupWithoutPictureHasNone() throws {
        let json = #"{"id":"2","type":"group","participants":{"items":[{"id":"a","imgURL":"file:///a.jpg"}]}}"#
        let chat = try JSONDecoder().decode(BeeperChatInfo.self, from: Data(json.utf8))
        #expect(chat.pictureURL == nil)
    }

    @Test func networkBotLeavesTheNameAndMakesItOneToOne() throws {
        let json = """
        {"id":"3","type":"group","title":"Agora Software, Anna","participants":{"items":[
          {"id":"me","isSelf":true},
          {"id":"org","fullName":"Agora Software","isNetworkBot":true},
          {"id":"anna","fullName":"Anna","imgURL":"file:///anna.jpg"}]}}
        """
        let chat = try JSONDecoder().decode(BeeperChatInfo.self, from: Data(json.utf8))
        #expect(chat.name == "Anna")
        #expect(!chat.isGroup)
        #expect(chat.pictureURL == "file:///anna.jpg")
    }

    @Test func googleChatNetworkIsRecognised() {
        #expect(BeeperNetworkBadge.isGoogleChat("Google Chat"))
        #expect(BeeperNetworkBadge.isGoogleChat("googlechat"))
        #expect(!BeeperNetworkBadge.isGoogleChat("WhatsApp"))
    }
}
