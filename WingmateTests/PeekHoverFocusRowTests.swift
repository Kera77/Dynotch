import Foundation
import Testing
@testable import Wingmate

/// Pop-ups held by the pointer, the Focus button's place, the finished task (spec E-36, FC-8, CN-10).
@MainActor
struct PeekHoverFocusRowTests {
    @Test func aHeldPopupGoesThreeSecondsAfterThePointerLeft() {
        let hover = PeekHover()
        let display = ObjectIdentifier(NSObject())
        let start = Date()
        #expect(hover.mayGo(.notification, now: start))
        hover.set(.notification, true, by: display, now: start)
        #expect(!hover.mayGo(.notification, now: start.addingTimeInterval(60)))
        hover.set(.notification, false, by: display, now: start.addingTimeInterval(10))
        #expect(!hover.mayGo(.notification, now: start.addingTimeInterval(12)))
        #expect(hover.mayGo(.notification, now: start.addingTimeInterval(13)))
        // Another kind is not held by it.
        #expect(hover.mayGo(.device, now: start))
    }

    @Test func onlySettingsStaysAtTheEnd() {
        #expect(TopRowControl.settings.isPinnedRight)
        #expect(!TopRowControl.focus.isPinnedRight)
    }

    @Test func theFinishedTaskIsTheLastPromptTyped() {
        let lines = [
            #"{"type":"user","message":{"role":"user","content":"Fix the   login\nbutton"}}"#,
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"Done: the button works."}]}}"#,
            #"{"type":"user","message":{"role":"user","content":"<command-name>/clear</command-name>"}}"#
        ]
        let work = ClaudeTranscript.finishedWork(in: lines.joined(separator: "\n"))
        #expect(work.task == "Fix the login button")
        #expect(work.answer == "Done: the button works.")
    }
}
