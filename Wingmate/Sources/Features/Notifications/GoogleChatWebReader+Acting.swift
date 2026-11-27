import ApplicationServices
import Foundation

// Acting in the web app: opening a conversation, writing, sending, going Home (spec GW-8, GW-9, GW-30).
extension GoogleChatWebReader {
    /// Opens a conversation in the web app, in the background (spec GW-8).
    nonisolated static func open(_ conversationID: String, pid: pid_t, windowToken: UInt64?) -> Bool {
        var walker = Walker()
        // The sidebar comes first: the walk stops at the link instead of reading the whole page (spec GW-20b).
        walker.stopAtLink = conversationID
        for window in AXWindows.all(pid: pid, hint: windowToken).0 { walker.walk(window) }
        guard let link = walker.links[conversationID] else { return false }
        return AXUIElementPerformAction(link, kAXPressAction as CFString) == .success
    }

    /// Writes into the open conversation's message box; true when it then holds the text.
    nonisolated static func write(_ text: String, pid: pid_t, windowToken: UInt64?) -> Bool {
        var walker = Walker()
        for window in AXWindows.all(pid: pid, hint: windowToken).0 { walker.walk(window) }
        guard let composer = walker.composer else { return false }
        return write(text, into: composer)
    }

    nonisolated private static func write(_ text: String, into composer: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(composer, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        guard AXUIElementSetAttributeValue(composer, kAXValueAttribute as CFString, text as CFString) == .success else { return false }
        let written = AXRead.string(composer, kAXValueAttribute) ?? ""
        return written.trimmingCharacters(in: .whitespacesAndNewlines) == text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Writes and presses send from one walk of the page (spec GW-31): the button is pressed
    /// once the web app enabled it for the text, tried for at most ~0.5 s.
    /// - Returns: whether send was pressed; when not, the box is emptied again.
    nonisolated static func writeAndSend(_ text: String, pid: pid_t, windowToken: UInt64?) -> Bool {
        var walker = Walker()
        for window in AXWindows.all(pid: pid, hint: windowToken).0 { walker.walk(window) }
        guard let composer = walker.composer, write(text, into: composer) else { return false }
        if let button = walker.sendButton {
            for attempt in 0..<10 {
                if AXRead.bool(button, kAXEnabledAttribute) != false {
                    if AXUIElementPerformAction(button, kAXPressAction as CFString) == .success { return true }
                    break
                }
                if attempt < 9 { Thread.sleep(forTimeInterval: 0.05) }
            }
        }
        // The button was not there yet (it may appear with the text): one more look.
        if pressSend(pid: pid, windowToken: windowToken) { return true }
        _ = write("", into: composer)
        return false
    }

    /// Presses the send button, only when it is enabled (it is once the web app took the text).
    nonisolated static func pressSend(pid: pid_t, windowToken: UInt64?) -> Bool {
        var walker = Walker()
        for window in AXWindows.all(pid: pid, hint: windowToken).0 { walker.walk(window) }
        guard let button = walker.sendButton, AXRead.bool(button, kAXEnabledAttribute) != false else { return false }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    /// Back to the Home list, in the background (spec GW-30): an open conversation would mark
    /// its new messages read, and only Home shows the previews (GW-21).
    nonisolated static func goHome(pid: pid_t, windowToken: UInt64?) -> Bool {
        var walker = Walker()
        walker.stopAtHome = true
        for window in AXWindows.all(pid: pid, hint: windowToken).0 { walker.walk(window) }
        guard let home = walker.homeLink else { return false }
        return AXUIElementPerformAction(home, kAXPressAction as CFString) == .success
    }
}
