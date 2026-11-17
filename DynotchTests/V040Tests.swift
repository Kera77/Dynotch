@testable import Dynotch
import Foundation
import Testing

/// v0.40: emoticons (spec E-18), answering a line (spec E-17), the pill (spec D-7).
struct V040Tests {
    @Test func emoticonsBecomeEmojiAsWords() {
        #expect(Emoticons.replace(in: "Hi :D ", includingLast: false) == "Hi 😄 ")
        // While typing, the last word waits for a space.
        #expect(Emoticons.replace(in: "Hi :D", includingLast: false) == "Hi :D")
        #expect(Emoticons.replace(in: "Hi :D", includingLast: true) == "Hi 😄")
        #expect(Emoticons.replace(in: ":) ok <3", includingLast: true) == "🙂 ok ❤️")
        // Links and times stay.
        #expect(Emoticons.replace(in: "https://x.com at 12:30 ", includingLast: true) == "https://x.com at 12:30 ")
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

    @Test @MainActor func externalDisplaysShowANotchByDefault() {
        let name = "V040Tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: defaults)
        #expect(settings.externalStyle == .notch)
        settings.externalStyle = .pill
        #expect(AppSettings(defaults: defaults).externalStyle == .pill)
    }
}
