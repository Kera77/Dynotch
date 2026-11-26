@testable import Dynotch
import Foundation
import Testing

/// Beeper in the notch (spec BP-1…BP-11), unread chats (spec UM-1…UM-8), connected devices
/// (spec DV-1…DV-7).
struct BeeperDevicesTests {
    @Test func earbudsShowLeftRightAndCase() throws {
        let json = """
        {"SPBluetoothDataType":[{"device_connected":[{"Peter’s AirPods Pro":{"device_batteryLevelLeft":"80%",
        "device_batteryLevelRight":"78%","device_batteryLevelCase":"100%"}},{"Magic Mouse":{"device_batteryLevelMain":"64%"}}]}]}
        """
        let data = try #require(json.data(using: .utf8))
        #expect(DeviceBattery.levels(named: "Peter’s AirPods Pro", json: data) == "L 80%  R 78%  Case 100%")
        #expect(DeviceBattery.levels(named: "Magic Mouse", json: data) == "64%")
        #expect(DeviceBattery.levels(named: "Other", json: data) == nil)
    }

    @Test func driveSizes() {
        #expect(DiskImages.sizeText(total: nil, free: nil, isImage: true) == "Disk image")
        #expect(DiskImages.sizeText(total: 1_000_000_000, free: 250_000_000, isImage: false)?.contains("free of") == true)
        #expect(DiskImages.sizeText(total: 100_000_000, free: nil, isImage: true)?.hasPrefix("Disk image · ") == true)
    }

    @Test func beeperMessagesDecode() throws {
        let json = """
        {"items":[{"id":"m2","chatID":"c","senderID":"me","text":"Hi","timestamp":"2026-11-17T10:00:01.500Z","sortKey":"2","isSender":true,
        "reactions":[{"id":"r","participantID":"you","reactionKey":"👍"}]},
        {"id":"m1","chatID":"c","senderID":"you","senderName":"Anna","text":"Hello","timestamp":"2026-11-17T10:00:00Z","sortKey":"1",
        "attachments":[{"type":"img","fileName":"a.png","fileSize":2048}]}]}
        """
        struct Page: Decodable { let items: [BeeperFullMessage] }
        let page = try JSONDecoder().decode(Page.self, from: Data(json.utf8))
        #expect(page.items.count == 2)
        #expect(page.items[0].mine)
        #expect(page.items[0].reactions?.first?.reactionKey == "👍")
        #expect(page.items[1].attachments?.first?.fileName == "a.png")
        #expect(page.items[0].date != nil)
        #expect(page.items[1].date != nil)
    }

    @Test func networksGetTheirColourAndTheWideTabs() {
        #expect(BeeperStyle.network("WhatsApp").symbol == "phone.fill")
        #expect(BeeperStyle.network(nil).symbol == "bubble.left.and.bubble.right.fill")
        #expect(NotificationsTab.beeper.isWide && !NotificationsTab.googleChat.isWide)
        #expect(!NotificationsTab.all.isWide && !NotificationsTab.chats.isWide)
        #expect(MIMEType.kind(of: MIMEType.of(URL(fileURLWithPath: "/x/a.gif"))) == "gif")
        #expect(MIMEType.kind(of: MIMEType.of(URL(fileURLWithPath: "/x/a.pdf"))) == "file")
    }

    @Test func beeperNotificationsAreChats() {
        let note = AppNotification(
            id: 1, appIdentifier: "com.automattic.beeper.desktop", title: "Anna", subtitle: "", body: "hi", date: Date()
        )
        #expect(ChatSources.isBeeper(note))
    }
}

/// macOS's own Bluetooth banners moved into the notch (spec DV-9, DV-10).
struct BluetoothBannerTests {
    @Test func bannerNamesItsDevice() {
        let names = ["AirPods", "Peter’s AirPods Pro", "Magic Mouse"]
        #expect(BluetoothBanner.deviceName(in: "Bluetooth Peter's AirPods Pro Connected", names: names) == "Peter’s AirPods Pro")
        #expect(BluetoothBanner.deviceName(in: "Messages Anna: hello", names: names) == nil)
    }

    @Test func bannerButtonBecomesTheCallToAction() {
        #expect(BluetoothBanner.callToAction(from: ["AXPress", "Close", "Show Details", "Move to iPhone"]) == "Move to iPhone")
        #expect(BluetoothBanner.callToAction(from: ["AXPress", "Bezárás"]) == nil)
    }

    @Test func reconnectingWithoutDisconnectIsQuiet() {
        let now = Date()
        #expect(BluetoothRepeat.isRepeat(since: now.addingTimeInterval(-15 * 60), now: now, window: 1800))
        #expect(!BluetoothRepeat.isRepeat(since: now.addingTimeInterval(-31 * 60), now: now, window: 1800))
        #expect(!BluetoothRepeat.isRepeat(since: nil, now: now, window: 1800))
    }

    @Test func devicePeekHasRoomBelowTheNotch() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663.5, auxiliaryRightWidth: 663.5, menuBarHeight: 32
        )
        // One row like "Claude finished", wider only for batteries and buttons (spec DV-15).
        #expect(geometry.devicePeekSize(levels: 0, actions: 0).height == geometry.notchSize.height + IndicatorLayout.labelHeight)
        #expect(geometry.devicePeekSize(levels: 0, actions: 0).width == max(geometry.notchSize.width + 140, IndicatorLayout.labelWidth))
        #expect(geometry.devicePeekSize(levels: 3, actions: 1).width > geometry.devicePeekSize(levels: 0, actions: 0).width)
    }
}
