import AppKit
import ApplicationServices

/// Replies in Google Chat when the notification names no conversation (spec E-11d): opens Google
/// Chat (its web app, or chat.google.com in the browser), ⌘⇧K, the conversation's name, Return,
/// and types only when the window or the focused field then shows that name. Otherwise nothing is
/// typed: the text is left on the clipboard.
@MainActor
enum GoogleChatJump {
    private static let chatURL = URL(string: "https://chat.google.com")

    static func send(_ text: String, to title: String, sourceApp: String, chatApp: String) async throws -> String {
        // "Sender (Space)": the space is the conversation; otherwise the person (spec E-11d).
        let conversation = conversationName(from: title)
        let webApp = chatApp.lowercased().hasPrefix("com.apple.safari.webapp")
            ? NSWorkspace.shared.urlForApplication(withBundleIdentifier: chatApp) : nil
        guard let appURL = webApp ?? TypedReply.appURL(for: sourceApp),
              let bundleID = Bundle(url: appURL)?.bundleIdentifier
        else { return try fail(text, "Google Chat could not be opened.") }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        if webApp != nil {
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }
        } else if let chatURL {
            NSWorkspace.shared.open([chatURL], withApplicationAt: appURL, configuration: configuration) { _, _ in }
        }
        guard await TypedReply.waitUntilFrontmost(bundleID) else { return try fail(text, "Google Chat didn't come to the front.") }
        await waitForChat(bundleID, isWebApp: webApp != nil)

        // ⌘⇧K: find a person, group or space; the name; Return opens it.
        let fieldBefore = AXRead.focusedField(of: bundleID)
        SyntheticInput.press(SyntheticInput.Key.letterK, flags: [.maskCommand, .maskShift])
        _ = await AXRead.wait(upTo: .milliseconds(600)) { !AXRead.same(AXRead.focusedField(of: bundleID), fieldBefore) }
        guard isFront(bundleID) else { return try fail(text, "Another app came to the front.") }
        let saved = SyntheticInput.Snapshot.take()
        SyntheticInput.put(conversation, transient: true)
        SyntheticInput.paste()
        // The search results come from the network: no sign to wait for.
        try? await Task.sleep(for: .milliseconds(1400))
        SyntheticInput.press(SyntheticInput.Key.returnKey)

        // Never type into a conversation that is not the one answered: the conversation's empty
        // message field must have the keyboard, and it or the window must name the conversation.
        // Checked until it holds, at most as long as it used to wait (spec RF-15).
        var check = Shown()
        _ = await AXRead.wait(upTo: .milliseconds(1800), step: .milliseconds(150)) {
            check = shownConversation(in: bundleID)
            return check.isMessageField && Self.matches(conversation, in: check.texts)
        }
        let named = Self.matches(conversation, in: check.texts)
        let titleNamed = check.texts.first.map { Self.matches(conversation, in: [$0]) } ?? false
        DiagnosticsLog.append(
            "reply", "google chat check: role=\(check.role) empty=\(check.isEmpty) titleNamed=\(titleNamed) named=\(named)"
        )
        guard isFront(bundleID), check.isMessageField, named else {
            SyntheticInput.press(SyntheticInput.Key.escape) // Closes the search if it is still open.
            saved.restore()
            return try fail(text, "Couldn't confirm the conversation in Google Chat. Text copied: paste it with ⌘V.")
        }
        SyntheticInput.put(text, transient: true)
        SyntheticInput.paste()
        try? await Task.sleep(for: .milliseconds(150))
        SyntheticInput.press(SyntheticInput.Key.returnKey)
        try? await Task.sleep(for: .milliseconds(400))
        saved.restore()
        DiagnosticsLog.append("reply", "google chat sent after jump")
        return "Sent in Google Chat"
    }

    /// Until its window shows Google Chat, at most as long as it used to wait (spec RF-15).
    private static func waitForChat(_ bundleID: String, isWebApp: Bool) async {
        try? await Task.sleep(for: .milliseconds(300))
        _ = await AXRead.wait(upTo: isWebApp ? .milliseconds(600) : .milliseconds(2700)) {
            guard let window = AXRead.focusedWindow(of: bundleID) else { return false }
            return isWebApp || (AXRead.string(window, kAXTitleAttribute) ?? "").localizedCaseInsensitiveContains("chat")
        }
    }

    private static func fail(_ text: String, _ message: String) throws -> String {
        TypedReply.copyToClipboard(text)
        throw TypedReply.Failure(description: message)
    }

    private static func isFront(_ bundleID: String) -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID
    }

    private struct Shown {
        /// The window title and the focused field's labels (never its value: that is our typing).
        var texts: [String] = []
        var role = "-"
        var isEmpty = false

        /// An empty multi-line field: the message box, not the search (spec E-11d).
        var isMessageField: Bool { role == (kAXTextAreaRole as String) && isEmpty }
    }

    /// "Jane Doe (Support - Team)" → "Support - Team"; a person's name stays.
    nonisolated static func conversationName(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(")"), let open = trimmed.lastIndex(of: "(") else { return trimmed }
        let inner = trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)]
        let space = inner.trimmingCharacters(in: .whitespaces)
        return space.isEmpty ? trimmed : space
    }

    /// The front window's title and the focused field's label and placeholder.
    private static func shownConversation(in bundleID: String) -> Shown {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID
        else { return Shown() }
        let app = AXUIElementCreateApplication(pid)
        var shown = Shown()
        let window = AXRead.element(app, kAXFocusedWindowAttribute)
        if let title = window.flatMap({ AXRead.string($0, kAXTitleAttribute) }) { shown.texts.append(title) }
        let field = AXRead.element(app, kAXFocusedUIElementAttribute)
        shown.texts += [kAXDescriptionAttribute, kAXPlaceholderValueAttribute, kAXHelpAttribute]
            .compactMap { attribute in field.flatMap { AXRead.string($0, attribute) } }
        shown.role = field.flatMap { AXRead.string($0, kAXRoleAttribute) } ?? "-"
        let value = field.flatMap { AXRead.string($0, kAXValueAttribute) } ?? ""
        shown.isEmpty = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return shown
    }

    /// Whether one of the texts names the conversation: its full name, or for a person their
    /// first and last name in any order; case and accents do not matter.
    nonisolated static func matches(_ conversation: String, in texts: [String]) -> Bool {
        let fold: (String) -> String = { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
        let name = fold(conversation.trimmingCharacters(in: .whitespaces))
        guard !name.isEmpty else { return false }
        let words = name.split(whereSeparator: \.isWhitespace).map(String.init).filter { $0.count >= 2 }
        return texts.map(fold).contains { text in
            text.contains(name) || (words.count >= 2 && words.allSatisfy { text.contains($0) })
        }
    }
}
