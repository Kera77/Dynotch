import CoreGraphics
@testable import Dynotch
import Foundation
import Testing

@MainActor
struct CallTests {
    @Test func buttonsAreRecognised() {
        #expect(CallMatcher.action(forLabel: "Accept") == .accept)
        #expect(CallMatcher.action(forLabel: "Answer") == .accept)
        #expect(CallMatcher.action(forLabel: "Decline") == .decline)
        #expect(CallMatcher.action(forLabel: "Elutasítás") == .decline)
        #expect(CallMatcher.action(forLabel: "Fogadás") == .accept)
        #expect(CallMatcher.action(forLabel: "Close") == nil)
        #expect(CallMatcher.action(forLabel: "") == nil)
    }

    @Test func phoneNumbers() {
        #expect(CallMatcher.isPhoneNumber("+36 30 123 4567"))
        #expect(CallMatcher.isPhoneNumber("(555) 010-9999"))
        #expect(!CallMatcher.isPhoneNumber("Wesley Tingey"))
        #expect(!CallMatcher.isPhoneNumber("12345"))
        #expect(!CallMatcher.isPhoneNumber("Room 1234567"))
    }

    @Test func callerAndOrigin() {
        let named = CallMatcher.describe(texts: ["from iPhone", "Wesley Tingey", "Decline", "Accept", "Wesley Tingey"])
        #expect(named.caller == "Wesley Tingey")
        #expect(named.detail == "from iPhone")

        let number = CallMatcher.describe(texts: ["+36 30 123 4567", "FaceTime Audio"])
        #expect(number.caller == "+36 30 123 4567")
        #expect(number.detail == "FaceTime Audio")

        let empty = CallMatcher.describe(texts: ["Accept", " "])
        #expect(empty.caller == "Incoming call")
        #expect(empty.detail.isEmpty)

        #expect(CallMatcher.initials(of: "Wesley Tingey") == "WT")
        #expect(CallMatcher.initials(of: "+36 30 123 4567").isEmpty)
    }

    @Test func aCallEndsAfterTwoMisses() {
        let name = "CallTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        let service = CallService(settings: AppSettings(defaults: defaults))
        // A process that cannot exist, so nothing is read from the system.
        let call = IncomingCall(pid: -1, caller: "Wesley Tingey", detail: "from iPhone")
        service.update(call)
        #expect(service.call == call)
        service.isComposing = true
        service.update(nil)
        #expect(service.call == call)
        service.update(nil)
        #expect(service.call == nil)
        #expect(!service.isComposing)
    }

    @Test func theCallCardFitsTheWindow() {
        let geometry = NotchGeometry.make(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
            auxiliaryLeftWidth: 663, auxiliaryRightWidth: 664, menuBarHeight: 32
        )
        let plain = geometry.callSize(composing: false)
        let composing = geometry.callSize(composing: true)
        #expect(composing.height > plain.height)
        #expect(composing.width <= geometry.windowSize.width)
        #expect(composing.height <= geometry.windowSize.height)
    }
}
