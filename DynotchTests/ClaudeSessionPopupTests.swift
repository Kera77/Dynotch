@testable import Dynotch
import Foundation
import Testing

/// The usage dropped down with the sessions (spec CS-6, CS-7).
@MainActor
struct ClaudeSessionPopupTests {
    private func event(_ name: String, _ id: String = "s1", at date: Date) -> ClaudeSessionEvent {
        let input: [String: Any] = ["hook_event_name": name, "session_id": id, "cwd": "/tmp/dynotch"]
        guard let event = ClaudeSessionEvent(input: input, app: nil, date: date) else { preconditionFailure("bad event") }
        return event
    }

    @Test func aNewSessionPopsUpAndItsXClosesIt() {
        let service = ClaudeSessionService()
        let start = Date()
        service.handle(event("SessionStart", at: start))
        #expect(service.popupShown)
        service.closePopup()
        // The same session's next prompt does not bring it back; a new session does.
        service.handle(event("UserPromptSubmit", at: start.addingTimeInterval(5)))
        #expect(!service.popupShown)
        service.handle(event("UserPromptSubmit", "s2", at: start.addingTimeInterval(6)))
        #expect(service.popupShown)
    }

    @Test func itGoesTenMinutesAfterTheLastSessionEnded() {
        let service = ClaudeSessionService()
        let start = Date()
        service.handle(event("UserPromptSubmit", at: start))
        // Still working: it stays however long.
        service.checkPopup(now: start.addingTimeInterval(3600))
        #expect(service.popupShown)
        let stop = start.addingTimeInterval(3700)
        service.handle(event("Stop", at: stop))
        service.checkPopup(now: stop.addingTimeInterval(9 * 60))
        #expect(service.popupShown)
        // Hovering starts the ten minutes again.
        service.touchPopup(at: stop.addingTimeInterval(9 * 60))
        service.checkPopup(now: stop.addingTimeInterval(11 * 60))
        #expect(service.popupShown)
        service.checkPopup(now: stop.addingTimeInterval(20 * 60))
        #expect(!service.popupShown)
    }

    @Test func theHoverListsRunningAndJustFinishedSessions() {
        let service = ClaudeSessionService()
        let start = Date()
        service.handle(event("UserPromptSubmit", "a", at: start))
        service.handle(event("UserPromptSubmit", "b", at: start))
        service.handle(event("Stop", "b", at: start))
        #expect(service.running(now: start.addingTimeInterval(60)).count == 2)
        #expect(service.running(now: start.addingTimeInterval(11 * 60)).map(\.id) == ["a"])
        let item = IndicatorItem.usage([], sessions: service.running(now: start))
        #expect(item.labelHeight > IndicatorItem.usage([]).labelHeight)
    }
}
