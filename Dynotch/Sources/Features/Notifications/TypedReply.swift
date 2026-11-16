import AppKit
import ApplicationServices

/// Replies to chats that have no API (e.g. Google Chat in a browser) by opening the conversation
/// and typing into it: paste, then Return (spec E-11b). Needs Accessibility.
@MainActor
enum TypedReply {
    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    /// How long the conversation may take to come to the front, and to load.
    private static let activationTimeout: Duration = .seconds(6)
    private static let loadDelay: Duration = .milliseconds(2500)

    static func send(_ text: String, link: URL?, sourceApp: String, fallbackApp: String) async throws -> String {
        guard AXIsProcessTrusted() else {
            throw Failure(description: "Replying needs Accessibility access (Settings › Notifications).")
        }
        guard let link, let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: sourceApp)
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: fallbackApp)
        else {
            // Without the conversation's address the text could land in the wrong chat.
            copyToClipboard(text)
            if let fallback = NSWorkspace.shared.urlForApplication(withBundleIdentifier: fallbackApp) {
                NSWorkspace.shared.openApplication(at: fallback, configuration: NSWorkspace.OpenConfiguration())
            }
            throw Failure(description: "The notification doesn't name its conversation. Text copied: paste it with ⌘V.")
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([link], withApplicationAt: appURL, configuration: configuration) { _, _ in }

        let bundleID = Bundle(url: appURL)?.bundleIdentifier ?? sourceApp
        guard await waitUntilFrontmost(bundleID) else {
            copyToClipboard(text)
            throw Failure(description: "The conversation didn't open. Text copied: paste it with ⌘V.")
        }
        try? await Task.sleep(for: loadDelay)
        // Check again right before typing: never type into another app.
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID else {
            copyToClipboard(text)
            throw Failure(description: "Another app came to the front. Text copied: paste it with ⌘V.")
        }

        let saved = NSPasteboard.general.string(forType: .string)
        copyToClipboard(text)
        press(key: 0x09, flags: .maskCommand) // V
        try? await Task.sleep(for: .milliseconds(150))
        press(key: 0x24, flags: []) // Return
        try? await Task.sleep(for: .milliseconds(400))
        if let saved { copyToClipboard(saved) }
        return "Sent in \(FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: ""))"
    }

    private static func waitUntilFrontmost(_ bundleID: String) async -> Bool {
        let deadline = ContinuousClock.now + activationTimeout
        while ContinuousClock.now < deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID { return true }
            try? await Task.sleep(for: .milliseconds(150))
        }
        return false
    }

    private static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func press(key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }
}
