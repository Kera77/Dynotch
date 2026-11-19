import AppKit
import Combine

/// Collects a process's output into lines; filled from a background queue.
private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()

    func append(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        pending.append(data)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            let line = pending.subdata(in: pending.startIndex..<newline)
            pending.removeSubrange(pending.startIndex...newline)
            if let text = String(data: line, encoding: .utf8), !text.isEmpty { lines.append(text) }
        }
        return lines
    }
}

/// Chats with Claude in the notch (spec CC-1…CC-5), through the Claude Code program.
@MainActor
final class ClaudeChatService: ObservableObject {
    /// Newest first.
    @Published private(set) var chats: [ClaudeChat] = []
    /// nil: a new chat that has no question yet.
    @Published private(set) var selectedID: UUID?
    @Published var draft = ""
    /// The chat Claude is answering in.
    @Published private(set) var workingID: UUID? {
        didSet { if indicator.isWorking != isWorking { indicator.isWorking = isWorking } }
    }
    /// Only whether an answer is being written, for the notch (spec N-16).
    let indicator = ChatIndicator()
    /// The chat is on screen in the notch or in the menu bar panel; an answer arriving
    /// meanwhile needs no notice.
    var isVisible = false
    var isVisibleInMenuBar = false
    /// Claude Code's own sessions that were not taken over yet (spec CC-6).
    @Published private(set) var codeSessions: [ClaudeCodeSession] = []
    /// The claude.ai and chatgpt.com conversations from the browsers' history (spec AI-17).
    @Published private(set) var webConversations: [WebAIConversation] = []
    /// The list of earlier chats is shown (spec CC-7).
    @Published var showsSidebar: Bool {
        didSet { defaults.set(!showsSidebar, forKey: Self.sidebarKey) }
    }

    /// The service new chats use (spec AI-1); the default comes from the settings.
    @Published var provider: AIProvider {
        didSet { defaults.set(provider.rawValue, forKey: Self.providerKey) }
    }
    /// Answers with more thinking (spec AI-2).
    @Published var thinksHarder = false
    /// Files and images going with the next question (spec AI-5).
    @Published var attachments: [URL] = []
    /// The session Codex announced before its answer ended.
    var pendingSessions: [UUID: String] = [:]
    /// What the program wrote to its error output, for a useful message.
    var errorOutput: [UUID: String] = [:]

    static let providerKey = "aiDefaultProvider"
    private static let sidebarKey = "claudeChatSidebarHidden"
    let defaults: UserDefaults

    private let file: URL
    var process: Process?
    /// Called when an answer is ready while the chat is not on screen (spec CC-5).
    var onAnswerReady: (ClaudeChat) -> Void = { _ in }

    static var defaultFolder: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent("Dynotch", isDirectory: true)
    }

    init(
        file: URL = ClaudeChatService.defaultFolder.appendingPathComponent("claude-chats.json"),
        defaults: UserDefaults = .standard
    ) {
        self.file = file
        self.defaults = defaults
        showsSidebar = !defaults.bool(forKey: Self.sidebarKey)
        provider = defaults.string(forKey: Self.providerKey).flatMap(AIProvider.init(rawValue:)) ?? .claude
        if let data = try? Data(contentsOf: file), let stored = try? JSONDecoder().decode([ClaudeChat].self, from: data) {
            chats = stored.sorted { $0.updated > $1.updated }
        }
    }

    var isWorking: Bool { workingID != nil }

    var selected: ClaudeChat? {
        selectedID.flatMap { id in chats.first { $0.id == id } }
    }

    /// The panel grows downwards once there is a conversation to show (spec CC-3).
    var isTall: Bool { !(selected?.messages.isEmpty ?? true) }

    // MARK: - Chats

    func newChat() {
        selectedID = nil
        draft = ""
    }

    func select(_ id: UUID) {
        guard chats.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    func delete(_ id: UUID) {
        if workingID == id { stop() }
        chats.removeAll { $0.id == id }
        if selectedID == id { selectedID = nil }
        save()
    }

    func update(_ id: UUID, _ change: (inout ClaudeChat) -> Void) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else { return }
        change(&chats[index])
    }

    func save() {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(chats) { try? data.write(to: file, options: .atomic) }
    }

    // MARK: - Claude Code's history (spec CC-6)

    /// The history beside the chats: the questions asked on the web (spec AI-17). Claude Code's
    /// and Codex's own sessions are not listed.
    func refreshCodeSessions() {
        Task { [weak self] in
            let found = await Task.detached { WebAIHistory.conversations() }.value
            guard let self, found != self.webConversations else { return }
            self.webConversations = found
        }
    }

    func setCodeSessions(_ sessions: [ClaudeCodeSession]) {
        let taken = Set(chats.compactMap(\.importedFrom))
        let remaining = sessions.filter { !taken.contains($0.id) }
        if remaining != codeSessions { codeSessions = remaining }
    }

    /// Takes a Claude Code session over as a chat: its conversation is shown, and the next
    /// question continues a copy of it.
    func open(_ session: ClaudeCodeSession) {
        if let existing = chats.first(where: { $0.importedFrom == session.id }) {
            selectedID = existing.id
            return
        }
        var chat = ClaudeChat(title: session.title, sessionID: session.id)
        chat.workingDirectory = session.workingDirectory
        chat.importedFrom = session.id
        chat.needsFork = true
        chat.updated = session.modified
        chats.append(chat)
        chats.sort { $0.updated > $1.updated }
        selectedID = chat.id
        codeSessions.removeAll { $0.id == session.id }
        save()
        let id = chat.id
        let file = session.file
        Task { [weak self] in
            let messages = await Task.detached { ClaudeCodeHistory.messages(in: file) }.value
            self?.setImportedMessages(messages, for: id)
        }
    }

    func setImportedMessages(_ messages: [ChatMessage], for id: UUID) {
        // Only while nothing was asked in it yet.
        update(id) { chat in
            if chat.messages.isEmpty { chat.messages = messages }
        }
        save()
    }

    // MARK: - Asking

    /// Sends the draft: starts a chat if none is open, and asks Claude.
    func send() {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isWorking else { return }
        draft = ""
        let files = attachments
        attachments = []
        let id = begin(prompt)
        let service = chats.first { $0.id == id }?.service ?? provider
        switch service {
        case .claude:
            guard let program = ClaudeCLI.locate() else {
                let missing = "Claude Code was not found. Install it (or its VS Code extension) and sign in."
                finish(id, text: missing, sessionID: nil, isError: true)
                return
            }
            run(program, prompt: AIPrompt.withFiles(prompt, files), chatID: id, canRead: !files.isEmpty)
        case .chatgpt where chatGPTMode == .web:
            askOnChatGPTWeb(prompt: prompt, chatID: id)
        case .chatgpt:
            runCodex(prompt: prompt, files: files, chatID: id)
        }
    }

    /// Adds the question and an empty answer to the chat, creating the chat if needed.
    func begin(_ prompt: String) -> UUID {
        let id: UUID
        if let selectedID, chats.contains(where: { $0.id == selectedID }) {
            id = selectedID
        } else {
            var chat = ClaudeChat(title: ClaudeChat.title(for: prompt))
            chat.provider = provider
            chat.model = model(for: provider)
            chats.insert(chat, at: 0)
            id = chat.id
            selectedID = id
        }
        update(id) { chat in
            chat.messages.append(ChatMessage(role: .user, text: prompt))
            chat.messages.append(ChatMessage(role: .assistant, text: ""))
            chat.updated = Date()
        }
        chats.sort { $0.updated > $1.updated }
        workingID = id
        save()
        return id
    }

    func apply(_ event: ClaudeStream.Event, to chatID: UUID) {
        switch event {
        case .delta(let text):
            guard workingID == chatID else { return }
            update(chatID) { chat in
                guard let last = chat.messages.indices.last, chat.messages[last].role == .assistant else { return }
                chat.messages[last].text += text
            }
        case .result(let text, let sessionID, let isError):
            finish(chatID, text: text, sessionID: sessionID, isError: isError)
        case .replace(let text):
            guard workingID == chatID else { return }
            update(chatID) { chat in
                guard let last = chat.messages.indices.last, chat.messages[last].role == .assistant else { return }
                chat.messages[last].text = text
            }
        case .session(let id):
            pendingSessions[chatID] = id
        }
    }

    /// The program ended without a result line (crashed, or was stopped).
    private func ended(_ chatID: UUID, status: Int32) {
        guard workingID == chatID else { return }
        let chat = chats.first { $0.id == chatID }
        let partial = chat?.messages.last?.text ?? ""
        let reason = errorOutput.removeValue(forKey: chatID) ?? "code \(status)"
        let name = chat?.service == .chatgpt ? "ChatGPT" : "Claude Code"
        finish(chatID, text: partial.isEmpty ? "\(name) ended without an answer (\(reason))." : partial,
               sessionID: nil, isError: partial.isEmpty)
    }

    func finish(_ chatID: UUID, text: String, sessionID: String?, isError: Bool) {
        guard workingID == chatID else { return }
        workingID = nil
        process = nil
        update(chatID) { chat in
            if let last = chat.messages.indices.last, chat.messages[last].role == .assistant {
                // The result repeats the streamed text; an error replaces it.
                if isError || chat.messages[last].text.isEmpty { chat.messages[last].text = text }
                chat.messages[last].isError = isError
            }
            if let sessionID = sessionID ?? pendingSessions[chatID], !isError {
                chat.sessionID = sessionID
                chat.needsFork = nil
            }
            chat.updated = Date()
        }
        pendingSessions[chatID] = nil
        errorOutput[chatID] = nil
        save()
        if !isVisible, !isVisibleInMenuBar, let chat = chats.first(where: { $0.id == chatID }) { onAnswerReady(chat) }
    }

    func stop() {
        guard let id = workingID else { return }
        process?.terminate()
        let partial = chats.first { $0.id == id }?.messages.last?.text ?? ""
        finish(id, text: partial.isEmpty ? "Stopped." : partial, sessionID: nil, isError: false)
    }
}

// MARK: - Running Claude Code or Codex

extension ClaudeChatService {
    func run(_ program: URL, prompt: String, chatID: UUID, canRead: Bool) {
        let chat = chats.first { $0.id == chatID }
        var folder = Self.chatFolder
        // A session taken over from Claude Code can only be continued from its own folder.
        if let directory = chat?.workingDirectory, FileManager.default.fileExists(atPath: directory) {
            folder = URL(fileURLWithPath: directory, isDirectory: true)
        }
        let arguments = ClaudeCLI.arguments(
            prompt: prompt, sessionID: chat?.sessionID, fork: chat?.needsFork == true, model: AIModel.current(chat?.model), canRead: canRead
        )
        launch(program, arguments: arguments, folder: folder, chatID: chatID, parse: ClaudeStream.event(fromLine:))
    }

    /// The folder the chats run in.
    static var chatFolder: URL {
        let folder = defaultFolder.appendingPathComponent(ClaudeCLI.folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Runs Claude Code or Codex and feeds its lines to the chat.
    func launch(
        _ program: URL, arguments: [String], folder: URL, chatID: UUID, parse: @escaping @Sendable (String) -> ClaudeStream.Event?
    ) {
        // More thinking for Claude (spec AI-2); Codex gets it as an argument.
        let extra = thinksHarder && chats.first(where: { $0.id == chatID })?.service == .claude ? ["MAX_THINKING_TOKENS": "16000"] : [:]
        let process = Process()
        process.executableURL = program
        process.arguments = arguments
        process.currentDirectoryURL = folder
        var environment = ProcessInfo.processInfo.environment.merging(extra) { $1 }
        // The login is looked up by user name.
        environment["USER"] = environment["USER"] ?? NSUserName()
        environment["LOGNAME"] = environment["LOGNAME"] ?? NSUserName()
        // Tells Dynotch's own Stop hook that this run reports its answer itself.
        environment["DYNOTCH_CHAT"] = "1"
        process.environment = environment

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        let buffer = LineBuffer()
        let errorBuffer = LineBuffer()
        errors.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let lines = errorBuffer.append(handle.availableData)
            guard let last = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return }
            Task { @MainActor in self?.errorOutput[chatID] = String(last.prefix(300)) }
        }
        let reader = output.fileHandleForReading
        reader.readabilityHandler = { [weak self] handle in
            let events = buffer.append(handle.availableData).compactMap(parse)
            guard !events.isEmpty else { return }
            Task { @MainActor in
                events.forEach { self?.apply($0, to: chatID) }
            }
        }
        process.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            reader.readabilityHandler = nil
            errors.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                // Let the last output be applied first.
                try? await Task.sleep(for: .milliseconds(150))
                self?.ended(chatID, status: status)
            }
        }
        do {
            try process.run()
            self.process = process
        } catch {
            finish(chatID, text: "Could not start it: \(error.localizedDescription)", sessionID: nil, isError: true)
        }
    }
}

/// Whether the AI is writing an answer: all the closed notch needs of the chat.
@MainActor
final class ChatIndicator: ObservableObject {
    @Published fileprivate(set) var isWorking = false
}
