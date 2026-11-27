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
    /// After the field appeared, a moment for the page to finish placing it.
    private static let settleDelay: Duration = .milliseconds(300)

    /// The app to type the reply in: a browser's notification opens in the browser in use now,
    /// any other in the app that sent it (spec E-2f).
    @MainActor
    static func appURL(for sourceApp: String) -> URL? {
        if WebNotificationSource.isShared(sourceApp), let browser = ActiveBrowser.shared.url() { return browser }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: sourceApp)
    }

    /// - Parameter conversation: the chat's name, for Google Chat notifications without a link.
    static func send(
        _ text: String, link: URL?, sourceApp: String, fallbackApp: String, conversation: String? = nil
    ) async throws -> String {
        guard AXIsProcessTrusted() else {
            throw Failure(description: "Replying needs Accessibility access (Settings › Notifications).")
        }
        if link == nil, let conversation, !conversation.isEmpty {
            // Google Chat names no conversation in its notifications: jump to it by name (spec E-11d).
            return try await GoogleChatJump.send(text, to: conversation, sourceApp: sourceApp, chatApp: fallbackApp)
        }
        guard let link, let appURL = appURL(for: sourceApp)
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: fallbackApp)
        else {
            // Without the conversation's address the text could land in the wrong chat.
            copyToClipboard(text)
            if let fallback = NSWorkspace.shared.urlForApplication(withBundleIdentifier: fallbackApp) {
                NSWorkspace.shared.openApplication(at: fallback, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
            throw Failure(description: "The notification doesn't name its conversation. Text copied: paste it with ⌘V.")
        }

        let bundleID = Bundle(url: appURL)?.bundleIdentifier ?? sourceApp
        // The field that had the keyboard before: the new conversation's field must be another one.
        let before = AXRead.focusedField(of: bundleID)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([link], withApplicationAt: appURL, configuration: configuration) { _, _ in }

        guard await waitUntilFrontmost(bundleID) else {
            copyToClipboard(text)
            throw Failure(description: "The conversation didn't open. Text copied: paste it with ⌘V.")
        }
        // Until a new text field has the keyboard, at most as long as it used to wait (spec RF-15).
        let loaded = await AXRead.wait(upTo: loadDelay) {
            guard let field = AXRead.focusedField(of: bundleID) else { return false }
            return AXRead.isTextInput(field) && !AXRead.same(field, before)
        }
        if loaded { try? await Task.sleep(for: settleDelay) }
        // Check again right before typing: never type into another app.
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID else {
            copyToClipboard(text)
            throw Failure(description: "Another app came to the front. Text copied: paste it with ⌘V.")
        }

        let saved = SyntheticInput.Snapshot.take()
        SyntheticInput.put(text, transient: true)
        SyntheticInput.paste()
        try? await Task.sleep(for: .milliseconds(150))
        SyntheticInput.press(SyntheticInput.Key.returnKey)
        try? await Task.sleep(for: .milliseconds(400))
        saved.restore()
        return "Sent in \(FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: ""))"
    }

    static func waitUntilFrontmost(_ bundleID: String) async -> Bool {
        let deadline = ContinuousClock.now + activationTimeout
        while ContinuousClock.now < deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID { return true }
            try? await Task.sleep(for: .milliseconds(150))
        }
        return false
    }

    /// Text left for the user to paste by hand (not transient: it may stay in the history).
    static func copyToClipboard(_ text: String) {
        SyntheticInput.put(text, transient: false)
    }
}
