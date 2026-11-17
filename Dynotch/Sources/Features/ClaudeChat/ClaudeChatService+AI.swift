import AppKit
import ApplicationServices

/// The question with the attached files (spec AI-5).
enum AIPrompt {
    static func withFiles(_ prompt: String, _ files: [URL]) -> String {
        guard !files.isEmpty else { return prompt }
        return prompt + "\n\nAttached files (read them):\n" + files.map { "- " + $0.path }.joined(separator: "\n")
    }
}

// MARK: - ChatGPT, models, context (spec AI-1…AI-12)

extension ClaudeChatService {
    /// ChatGPT through Codex, with the account the Mac is signed in with (spec AI-3).
    func runCodex(prompt: String, files: [URL], chatID: UUID) {
        guard let program = CodexCLI.locate() else {
            finish(chatID, text: "ChatGPT's Codex was not found. Install the ChatGPT app and sign in.", sessionID: nil, isError: true)
            return
        }
        let chat = chats.first { $0.id == chatID }
        let images = files.filter { ["png", "jpg", "jpeg", "gif", "heic", "webp"].contains($0.pathExtension.lowercased()) }
        let others = files.filter { !images.contains($0) }
        let arguments = CodexCLI.arguments(
            prompt: AIPrompt.withFiles(prompt, others), threadID: chat?.sessionID, model: chat?.model,
            thinksHarder: thinksHarder, images: images
        )
        launch(
            program, arguments: arguments, folder: Self.chatFolder, chatID: chatID,
            parse: CodexStream.event(fromLine:)
        )
    }

    // MARK: Models (spec AI-2)

    private static func modelKey(_ provider: AIProvider) -> String { "aiDefaultModel." + provider.rawValue }

    /// The default model of a service; nil: the service's own default.
    func model(for provider: AIProvider) -> String? {
        defaults.string(forKey: Self.modelKey(provider))
    }

    func setDefaultModel(_ model: String?, for provider: AIProvider) {
        defaults.set(model, forKey: Self.modelKey(provider))
        objectWillChange.send()
    }

    /// The model shown in the header: the chat's, or the default for a new chat.
    var shownModel: String? {
        selected.map { $0.model } ?? model(for: provider)
    }

    var shownProvider: AIProvider { selected?.service ?? provider }

    /// Another model for this chat (it continues with it) or for new chats.
    func choose(model: String?) {
        if let id = selected?.id {
            update(id) { $0.model = model }
            save()
        } else {
            setDefaultModel(model, for: provider)
        }
    }

    /// Another service: a chat with messages cannot change it, so a new chat starts.
    func choose(provider newProvider: AIProvider) {
        provider = newProvider
        if let chat = selected, chat.service != newProvider { newChat() }
    }

    // MARK: List (spec AI-11)

    func togglePin(_ id: UUID) {
        update(id) { $0.isPinned = $0.isPinned == true ? nil : true }
        save()
    }

    /// Pinned first, then the newest; filtered by title and text.
    func listedChats(matching search: String) -> [ClaudeChat] {
        let found = search.isEmpty ? chats : chats.filter { chat in
            chat.title.localizedCaseInsensitiveContains(search)
                || chat.messages.contains { $0.text.localizedCaseInsensitiveContains(search) }
        }
        return found.filter { $0.isPinned == true } + found.filter { $0.isPinned != true }
    }

    // MARK: Context (spec AI-5)

    /// The clipboard's text into the question, or its image as an attachment.
    func addClipboard() {
        let board = NSPasteboard.general
        if let text = board.string(forType: .string), !text.isEmpty {
            draft += (draft.isEmpty ? "" : "\n\n") + text
        } else if let image = NSImage(pasteboard: board), let file = Self.temporaryPNG(image) {
            attachments.append(file)
        }
    }

    /// The text selected in the app in front, through Accessibility.
    func addSelectedText() {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return }
        var selection: CFTypeRef?
        // swiftlint:disable:next force_cast
        let element = focused as! AXUIElement
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selection) == .success,
              let text = selection as? String, !text.isEmpty
        else { return }
        draft += (draft.isEmpty ? "" : "\n\n") + text
    }

    private static func temporaryPNG(_ image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        let file = chatFolder.appendingPathComponent("clipboard-\(UUID().uuidString.prefix(8)).png")
        return (try? png.write(to: file)) == nil ? nil : file
    }

    // MARK: Templates (spec AI-8)

    static let builtInTemplates = [
        "Translate into English:", "Translate into Hungarian:", "Summarise briefly:", "Rewrite it more politely:",
        "Explain simply:", "Fix the grammar and spelling:"
    ]
    private static let templatesKey = "aiTemplates"

    var customTemplates: [String] { defaults.stringArray(forKey: Self.templatesKey) ?? [] }

    func useTemplate(_ template: String) {
        draft = template + "\n" + draft
    }

    /// The question typed so far becomes a template.
    func saveTemplate() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !customTemplates.contains(text) else { return }
        defaults.set(customTemplates + [text], forKey: Self.templatesKey)
        objectWillChange.send()
    }

    func removeTemplate(_ template: String) {
        defaults.set(customTemplates.filter { $0 != template }, forKey: Self.templatesKey)
        objectWillChange.send()
    }

    // MARK: Using the answer (spec AI-7, AI-12)

    /// Pastes an answer into the app in front (after the notch closed).
    static func insert(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        let source = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Continues the chat in Terminal, in Claude Code or Codex (spec AI-12).
    func continueInTerminal(_ chat: ClaudeChat) {
        guard let session = chat.sessionID else { return }
        let program: URL?
        let command: String
        switch chat.service {
        case .claude:
            program = ClaudeCLI.locate()
            command = "--resume \(session)"
        case .chatgpt:
            program = CodexCLI.locate()
            command = "resume \(session)"
        }
        guard let program else { return }
        let folder = chat.workingDirectory ?? Self.chatFolder.path
        let line = "cd \(Self.quoted(folder)) && \(Self.quoted(program.path)) \(command)"
        let source = "tell application \"Terminal\"\nactivate\ndo script \"\(line.replacingOccurrences(of: "\"", with: "\\\""))\"\nend tell"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if error != nil { DiagnosticsLog.append("ai", "could not open Terminal") }
    }

    private static func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
