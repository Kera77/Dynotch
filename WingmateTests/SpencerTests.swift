import Foundation
import Testing
@testable import Wingmate

/// Spencer's layouts, the display setups and the countdown (spec SL-1…SL-6), two notices (spec E-30).
struct SpencerTests {
    @Test func layoutsComeFromTheListOutput() {
        let output = "Available layouts:\n  Mac+Monitor+iPad\n  Vibecode\n\n  2 Monitors\n"
        #expect(SpencerService.layouts(from: output) == ["Mac+Monitor+iPad", "Vibecode", "2 Monitors"])
        #expect(SpencerService.layouts(from: "Usage: spencer --list").isEmpty)
    }

    @Test func aDisplaySetupIsTheSameWhateverTheOrder() {
        let builtin = DisplayInfo(vendor: 1552, model: 41_138, serial: 0, name: "Built-in Retina Display", isBuiltin: true)
        let dell = DisplayInfo(vendor: 4268, model: 41_234, serial: 12_345, name: "DELL U2720Q", isBuiltin: false)
        let ipad = DisplayInfo(vendor: 1552, model: 1, serial: 0, name: "Peter's iPad", isBuiltin: false)
        let one = DisplaySetup.make([ipad, builtin, dell])
        let other = DisplaySetup.make([dell, ipad, builtin])
        #expect(one.key == other.key)
        #expect(one.title == "Built-in + DELL U2720Q + Peter's iPad")
        #expect(one.count == 3)
        #expect(DisplaySetup.make([builtin, dell]).key != one.key)
        // A monitor without a serial is told apart by its name.
        let noSerial = DisplayInfo(vendor: 4268, model: 41_234, serial: 0, name: "LG", isBuiltin: false)
        #expect(DisplaySetup.part(of: noSerial) == "4268-41234-LG")
        #expect(DisplaySetup.part(of: ipad) == "sidecar:Peter's iPad")
    }

    @Test func theCancelRimRunsOutInTenSeconds() {
        let start = Date(timeIntervalSince1970: 1000)
        let interval = DateInterval(start: start, duration: 10)
        #expect(CountdownCancelPill.remaining(of: interval, at: start) == 1)
        #expect(abs(CountdownCancelPill.remaining(of: interval, at: start.addingTimeInterval(2.5)) - 0.75) < 0.0001)
        #expect(CountdownCancelPill.remaining(of: interval, at: start.addingTimeInterval(12)) == 0)
    }

    @MainActor @Test func assignmentsAndTheSwitchAreKept() throws {
        let defaults = try #require(UserDefaults(suiteName: "SpencerTests-\(UUID().uuidString)"))
        let service = SpencerService(defaults: defaults)
        #expect(service.autoSwitch)
        service.autoSwitch = false
        defaults.set(["a+b": "2 Monitors"], forKey: SpencerService.assignmentsKey)
        let again = SpencerService(defaults: defaults)
        #expect(!again.autoSwitch)
        #expect(again.assignments["a+b"] == "2 Monitors")
    }

    @Test func aNewNoticeStandsOverTheEarlierOne() {
        let date = Date()
        let whatsNew = StickyNotice(title: "Wingmate updated", detail: "", date: date, symbol: "sparkles", whatsNew: [])
        let claude = StickyNotice(title: "Claude finished", detail: "app", date: date)
        let claudeAgain = StickyNotice(title: "Claude finished", detail: "other", date: date)
        let spencer = StickyNotice(title: "Switching to X", detail: "", date: date, symbol: "rectangle.3.group", sourceName: "Spencer")

        let first = NoticeService.stacked(top: whatsNew, second: nil, new: claude)
        #expect(first.top == claude && first.second == whatsNew)
        // The same source replaces its own notice.
        let second = NoticeService.stacked(top: claude, second: whatsNew, new: claudeAgain)
        #expect(second.top == claudeAgain && second.second == whatsNew)
        // At most two: What's new never drops out.
        let third = NoticeService.stacked(top: claude, second: whatsNew, new: spencer)
        #expect(third.top == spencer && third.second == whatsNew)
        let fourth = NoticeService.stacked(top: claude, second: nil, new: spencer)
        #expect(fourth.second == claude)
    }

    @MainActor @Test func dismissingTheTopNoticeMovesTheOtherUp() {
        let notices = NoticeService()
        let claude = StickyNotice(title: "Claude finished", detail: "", date: Date())
        let spencer = StickyNotice(title: "Switching to X", detail: "", date: Date(), sourceName: "Spencer")
        notices.show(claude)
        notices.show(spencer)
        #expect(notices.second == claude)
        notices.dismiss()
        #expect(notices.notice == claude && notices.second == nil)
        #expect(!notices.isShown(spencer))
    }
}

/// Layouts by their displays, from Spencer's database (spec SL-7…SL-9).
struct SpencerLayoutDisplayTests {
    @Test func layoutsAreGreyedOrMatchedByTheirDisplays() {
        let output = "Mac+iPad\t37d8832a\nMac+iPad\tB545\nMacBook\t37D8832A\n2 Monitors\tAAA\n2 Monitors\tBBB\nbroken line\n"
        let found = SpencerLayoutDisplays.parse(output)
        #expect(found.displays["Mac+iPad"] == ["37D8832A", "B545"])
        let order = ["2 Monitors", "Mac+iPad", "MacBook"]
        #expect(found.matching(["37D8832A", "B545"], order: order) == "Mac+iPad")
        #expect(found.matching(["37D8832A"], order: order) == "MacBook")
        #expect(found.matching(["37D8832A", "CCC"], order: order) == nil)
        #expect(found.isAvailable("MacBook", connected: ["37D8832A", "B545"]))
        // One of its displays is enough (spec SL-12): the built-in alone keeps Mac+iPad.
        #expect(found.isAvailable("Mac+iPad", connected: ["37D8832A"]))
        #expect(found.isAvailable("2 Monitors", connected: ["37D8832A", "AAA"]))
        #expect(!found.isAvailable("2 Monitors", connected: ["37D8832A"]))
        #expect(found.isAvailable("Unknown", connected: []))
    }

    @Test func aDisplaySetupKeepsTheUUIDs() {
        let builtin = DisplayInfo(vendor: 1, model: 2, serial: 0, name: "Built-in", isBuiltin: true, uuid: "abc")
        #expect(DisplaySetup.make([builtin]).uuids == ["ABC"])
    }
}
