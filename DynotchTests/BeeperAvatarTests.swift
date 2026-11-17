@testable import Dynotch
import Foundation
import Testing

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
}
