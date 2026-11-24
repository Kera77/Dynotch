import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

/// Recognising screen sharing.
struct ScreenShareTests {
    @Test func sharingIndicatorsAreRecognised() {
        func window(_ owner: String, _ name: String, layer: Int = 0) -> ListedWindow {
            ListedWindow(owner: owner, name: name, layer: layer)
        }
        #expect(ScreenShareWatcher.isSharing([window("Google Chrome", "meet.google.com is sharing your screen.")]))
        #expect(ScreenShareWatcher.isSharing([window("Zen", "Zen — Sharing Indicator")]))
        #expect(ScreenShareWatcher.isSharing([window("zoom.us", "zoom share toolbar window")]))
        #expect(ScreenShareWatcher.isSharing([window("screencaptureui", "", layer: 25)]))
        #expect(!ScreenShareWatcher.isMeetingShare([window("screencaptureui", "", layer: 25)]))
        #expect(ScreenShareWatcher.isMeetingShare([window("zoom.us", "zoom share toolbar window")]))
        #expect(!ScreenShareWatcher.isSharing([window("Google Chrome", "Inbox - Gmail"), window("zoom.us", "Zoom Meeting")]))
    }
}
