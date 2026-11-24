@testable import Dynotch
import Foundation
import Testing

/// Pinned Google Chat names, the iPad menu's place, Focus exceptions (spec GW-27, TB-9, E-20d).
struct V0101Tests {
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

    @Test func tabletMenuOpensCentredBelowTheButton() {
        let point = MenuAnchor.centred(below: CGRect(x: 100, y: 900, width: 30, height: 22), menuWidth: 200)
        #expect(point == CGPoint(x: 15, y: 896))
    }

    @Test func allowedDuringFocusIsNotTheDefaultRule() {
        var rule = NotificationRule()
        #expect(rule.isDefault)
        rule.popsUpDuringFocus = true
        #expect(!rule.isDefault)
    }
}
