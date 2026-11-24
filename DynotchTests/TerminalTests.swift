@testable import Dynotch
import Foundation
import Testing

/// The terminal's dropped paths and wing.
@MainActor
struct TerminalTests {
    @Test func droppedPathsAreQuotedForTheShell() {
        #expect(TerminalPaths.quoted(["/tmp/a b"]) == "'/tmp/a b'")
        #expect(TerminalPaths.quoted(["/x/it's", "/y"]) == #"'/x/it'\''s' '/y'"#)
    }

    @Test func terminalWingCountsTabs() {
        #expect(TerminalWing.tabs(0) == "No shell running")
        #expect(TerminalWing.tabs(1) == "1 tab")
        #expect(TerminalWing.tabs(3) == "3 tabs")
    }
}
