import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// The message pop-up, the measured card, screen sharing.
struct V052Tests {
    @Test func linesCapThePopUpButNotTheCard() {
        let long = String(repeating: "Hosszú üzenet szövege, ami több sorba tördelődik. ", count: 12)
        let one = NotificationTextLayout.height(of: "Szia", width: 300, fontSize: 12, maxLines: 4)
        let capped = NotificationTextLayout.height(of: long, width: 300, fontSize: 12, maxLines: 4)
        let full = NotificationTextLayout.height(of: long, width: 300, fontSize: 12)
        #expect(abs(capped - 4 * one) < 1)
        #expect(full > capped)
    }

    @Test func popUpGrowsWithMessagesUpToItsLimit() {
        let short = NotificationTextLayout.peekHeight(texts: ["Szia"], notchHeight: 32, maxLines: 4)
        let two = NotificationTextLayout.peekHeight(texts: ["Szia", "Mizu?"], notchHeight: 32, maxLines: 4)
        let many = NotificationTextLayout.peekHeight(texts: Array(repeating: "Üzenet", count: 50), notchHeight: 32, maxLines: 4)
        #expect(two > short)
        #expect(many <= 32 + 24 + NotificationTextLayout.maxPeekTextHeight + 10)
    }

    @Test func hoveredCardStopsAtItsLimitAndScrolls() {
        let texts = Array(repeating: String(repeating: "szöveg ", count: 60), count: 10)
        #expect(NotificationTextLayout.stackHeight(texts: texts, notchHeight: 32) == NotificationTextLayout.maxStackHeight)
        #expect(NotificationTextLayout.stackHeight(texts: ["Szia"], notchHeight: 32) < 200)
    }

    @Test func oldRulesStillDecode() throws {
        let rule = try JSONDecoder().decode(NotificationRule.self, from: Data(#"{"hidesBanner":true}"#.utf8))
        #expect(rule.peekShowsMessage == nil)
        #expect(!rule.isDefault)
        #expect(NotificationRule(peekShowsMessage: true).isDefault == false)
    }

    @Test func sharingIndicatorsAreRecognised() {
        func window(_ owner: String, _ name: String, layer: Int = 0) -> [String: Any] {
            [kCGWindowOwnerName as String: owner, kCGWindowName as String: name, kCGWindowLayer as String: layer]
        }
        #expect(ScreenShareWatcher.isSharing([window("Google Chrome", "meet.google.com is sharing your screen.")]))
        #expect(ScreenShareWatcher.isSharing([window("Zen", "Zen — Sharing Indicator")]))
        #expect(ScreenShareWatcher.isSharing([window("zoom.us", "zoom share toolbar window")]))
        #expect(ScreenShareWatcher.isSharing([window("screencaptureui", "", layer: 25)]))
        #expect(!ScreenShareWatcher.isSharing([window("Google Chrome", "Inbox - Gmail"), window("zoom.us", "Zoom Meeting")]))
    }
}
