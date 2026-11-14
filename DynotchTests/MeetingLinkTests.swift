@testable import Dynotch
import Foundation
import Testing

struct MeetingLinkTests {
    @Test(arguments: [
        "https://us02web.zoom.us/j/81234567890?pwd=abc",
        "https://meet.google.com/abc-defg-hij",
        "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0",
        "https://teams.live.com/meet/9876543210",
        "https://acme.webex.com/meet/jdoe",
    ])
    func recognizesMeetingLinks(_ link: String) throws {
        let url = try #require(URL(string: link))
        #expect(MeetingLink.meetingURL(from: url) == url)
    }

    @Test(arguments: [
        "https://zoom.us/pricing",
        "https://meet.google.com/",
        "https://example.com/j/123",
        "https://teams.microsoft.com/v2/",
    ])
    func ignoresOtherLinks(_ link: String) throws {
        let url = try #require(URL(string: link))
        #expect(MeetingLink.meetingURL(from: url) == nil)
    }

    @Test func findsGoogleMeetLinkInNotes() {
        let notes = """
        Agenda: weekly sync
        Join with Google Meet: https://meet.google.com/xyz-abcd-efg
        Or dial: +36 1 234 5678
        """
        let found = MeetingLink.find(url: nil, texts: [nil, notes])
        #expect(found?.absoluteString == "https://meet.google.com/xyz-abcd-efg")
    }

    @Test func prefersEventURLAndSkipsNonMeetingLinks() {
        let notes = "Docs: https://example.com/doc  Zoom: https://zoom.us/j/111"
        #expect(MeetingLink.find(url: URL(string: "https://example.com"), texts: [notes])?.absoluteString
            == "https://zoom.us/j/111")
        #expect(MeetingLink.find(url: URL(string: "https://zoom.us/j/222"), texts: [notes])?.absoluteString
            == "https://zoom.us/j/222")
    }

    @Test func unwrapsOutlookSafeLinks() throws {
        let inner = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x%40thread.v2/0"
        var components = URLComponents(string: "https://eur01.safelinks.protection.outlook.com/")
        components?.queryItems = [URLQueryItem(name: "url", value: inner), URLQueryItem(name: "data", value: "x")]
        let wrapped = try #require(components?.url)
        #expect(MeetingLink.meetingURL(from: wrapped)?.absoluteString == inner)
    }

    @Test func returnsNilWithoutLinks() {
        #expect(MeetingLink.find(url: nil, texts: ["Tárgyaló 3", nil, ""]) == nil)
    }
}
