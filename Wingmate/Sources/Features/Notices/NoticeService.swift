import AppKit
import Observation

@MainActor
@Observable
final class NoticeService {
    var notice: StickyNotice?
    /// The earlier notice, in a compact row under the newer one (spec E-30). What's new waits
    /// here while another notice stands in its place (spec WN-7).
    private(set) var second: StickyNotice?

    /// The Claude Code sessions of the Sessions tab, fed by the same hooks (spec CS-3).
    let sessions = ClaudeSessionService()
    /// Hooks still waiting for an answer from a notice (spec CQ-6).
    @ObservationIgnored var waitingReplies: [String: ClaudeReplyRequest] = [:]
    @ObservationIgnored var replyExpiry: Task<Void, Never>?
    @ObservationIgnored var activationObserver: NSObjectProtocol?
    @ObservationIgnored private var downloadExpiry: Task<Void, Never>?
    @ObservationIgnored private var expiry: Task<Void, Never>?
    /// How long a finished download stays (spec PV-57).
    static let downloadStays: TimeInterval = 3
    /// "Claude finished" swiped down: its task and answer show under it (spec CN-10).
    var revealsTask = false

    /// The rows the swiped-down "Claude finished" adds under itself (spec CN-10).
    var taskRowsHeight: CGFloat {
        guard revealsTask, let notice, notice.task != nil else { return 0 }
        return notice.answer == nil ? 40 : 60
    }

    func show(_ notice: StickyNotice) {
        // Nothing pops up during the tour (spec OB-11).
        guard !OnboardingController.isRunning else { return }
        revealsTask = false
        let stack = Self.stacked(top: self.notice, second: second, new: notice)
        self.notice = stack.top
        second = stack.second
        settleReplies()
        expiry?.cancel()
        guard let stays = notice.stays else { return }
        expiry = Task { [weak self] in
            // Under the pointer it stays (spec E-36).
            await PeekHover.shared.wait(.notice, seconds: stays)
            guard !Task.isCancelled, let self else { return }
            self.remove(notice)
        }
    }

    /// The new notice on top, the one it covers under it, at most two (spec E-30). The same
    /// source's new notice replaces its old one; What's new never drops out (spec WN-7); a
    /// finished download only passes by (spec PV-57).
    nonisolated static func stacked(
        top: StickyNotice?, second: StickyNotice?, new: StickyNotice
    ) -> (top: StickyNotice, second: StickyNotice?) {
        var earlier = [top, second].compactMap { $0 }.filter { $0.download == nil }
        if new.whatsNew == nil { earlier.removeAll { $0.whatsNew == nil && $0.source == new.source } }
        if new.whatsNew != nil { earlier.removeAll { $0.whatsNew != nil } }
        // What's new outlasts the others under the new one.
        let kept = earlier.first { $0.whatsNew != nil } ?? earlier.first
        return (new, kept)
    }

    /// Takes one notice away, wherever it stands; the one under it moves up.
    func remove(_ shown: StickyNotice) {
        if notice == shown {
            revealsTask = false
            notice = second
            second = nil
        } else if second == shown {
            second = nil
        }
        settleReplies()
    }

    /// The notice is still under the notch, on top or under it.
    func isShown(_ shown: StickyNotice) -> Bool {
        notice == shown || second == shown
    }

    /// Got it on What's new: the only way it goes (spec WN-6).
    func dismissWhatsNew() {
        if second?.whatsNew != nil { second = nil }
        if let notice, notice.whatsNew != nil { remove(notice) }
    }

    /// A finished download, unless something more important stands there; it goes by itself.
    func showDownload(_ file: URL) {
        if let notice, notice.download == nil { return }
        let shown = StickyNotice.downloaded(file)
        notice = shown
        RecentNotice.shared.note(.tray, file: file, id: "download:" + file.path)
        downloadExpiry?.cancel()
        downloadExpiry = Task { [weak self] in
            await PeekHover.shared.wait(.notice, seconds: Self.downloadStays)
            guard !Task.isCancelled, let self else { return }
            self.remove(shown)
        }
    }

    /// The top notice goes and the one under it moves up. What's new does not go this way,
    /// only with its Got it (spec WN-7).
    func dismiss() {
        guard let notice, notice.whatsNew == nil else { return }
        remove(notice)
    }

    /// The X on the earlier notice under the top one: only that one goes (spec E-35).
    func dismissSecond() {
        guard let second, second.whatsNew == nil else { return }
        remove(second)
    }

    /// Links other programs open to tell Wingmate something (spec CN-2).
    func handle(_ url: URL) {
        switch ClaudeQuestionHook.event(from: url, now: Date()) {
        case .asks(let question, let session):
            sessions.asks(session: session, needsYou: question.title != "Claude asks", at: question.date)
            showQuestion(question)
            return
        case .answered(let session):
            sessions.answered(session: session, at: Date())
            // The hook no longer waits: nothing to hand it.
            waitingReplies.removeAll()
            if notice?.isQuestion == true { dismiss() }
            return
        case .session(let event):
            sessions.handle(event)
            return
        case .ignored:
            return
        case nil:
            break
        }
        if let notice = CodexHook.notice(from: url, now: Date()) {
            DiagnosticsLog.append("claude-hook", "codex finished app=\(notice.appIdentifier ?? "-")")
            show(notice)
            return
        }
        guard let notice = ClaudeHook.notice(from: url, now: Date()) else { return }
        guard let transcript = ClaudeHook.transcriptPath(from: url) else {
            show(notice)
            return
        }
        // Claude also stops while background work is still running; that is not "finished".
        Task { [weak self] in
            let summary = await Task.detached { ClaudeTranscript.summary(ofFileAt: transcript) }.value
            let pending = summary.pending
            if pending.isEmpty {
                // The session may have worked in another folder than the one it was started in.
                let project = summary.project ?? notice.detail
                self?.show(StickyNotice(
                    title: notice.title, detail: project, date: notice.date, appIdentifier: notice.appIdentifier,
                    task: summary.task, answer: summary.answer
                ))
            } else {
                DiagnosticsLog.append("claude-hook", "stopped with \(pending.count) background task(s) running: no notice")
            }
        }
    }
}

/// Claude Code tells Wingmate that it finished a task through a "Stop" hook that opens a
/// wingmate:// link (spec CN-2).
enum ClaudeHook {
    static let marker = "wingmate://claude-finished"
    /// Opens the link in the background, with the project folder's name.
    /// Wingmate's own chat runs are skipped; the hook's input (which names the transcript) is kept
    /// in a temporary file whose name travels in the link.
    static let command = #"[ -n "$WINGMATE_CHAT" ] && exit 0; f=$(mktemp "${TMPDIR:-/tmp}/wingmate-stop.XXXXXX") && cat > "$f"; "#
        + #"open -g "wingmate://claude-finished?project=$(basename "$PWD" | sed 's/ /%20/g')&info=$(basename "$f")"#
        + #"&app=${__CFBundleIdentifier:-}""#

    /// The transcript of the session that stopped, from the hook's input file (which is removed).
    static func transcriptPath(from url: URL) -> String? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let name = items.first(where: { $0.name == "info" })?.value,
              name.hasPrefix("wingmate-stop."), !name.contains("/")
        else { return nil }
        for folder in [NSTemporaryDirectory(), "/tmp/"] {
            let file = URL(fileURLWithPath: folder).appendingPathComponent(name)
            guard let data = try? Data(contentsOf: file) else { continue }
            try? FileManager.default.removeItem(at: file)
            let input = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return input?["transcript_path"] as? String
        }
        return nil
    }

    /// Rewrites an installed hook that still has an older command.
    static func upgradeIfNeeded() {
        guard let settings = try? read(), isInstalled(in: settings) else { return }
        let isCurrent = stopGroups(in: settings).contains { group in
            (group["hooks"] as? [[String: Any]] ?? []).contains { $0["command"] as? String == command }
        }
        if !isCurrent { try? setInstalled(true) }
    }

    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    static func notice(from url: URL, now: Date) -> StickyNotice? {
        guard url.scheme?.lowercased() == "wingmate", url.host?.lowercased() == "claude-finished" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let project = items.first { $0.name == "project" }?.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Wingmate's own chat runs through Claude Code too; it reports its answers itself.
        guard project != ClaudeCLI.folderName else { return nil }
        // The app Claude Code ran in, brought forward by a click (spec CN-6).
        let app = items.first { $0.name == "app" }?.value.flatMap { $0.isEmpty ? nil : $0 }
        return StickyNotice(title: "Claude finished", detail: String(project.prefix(60)), date: now, appIdentifier: app)
    }

    // MARK: - Claude Code settings

    private static func stopGroups(in settings: [String: Any]) -> [[String: Any]] {
        ((settings["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]) ?? []
    }

    private static func isOurs(_ group: [String: Any]) -> Bool {
        (group["hooks"] as? [[String: Any]] ?? []).contains { ($0["command"] as? String ?? "").contains(marker) }
    }

    static func isInstalled(in settings: [String: Any]) -> Bool {
        stopGroups(in: settings).contains(where: isOurs)
    }

    /// The settings with (or without) Wingmate's Stop hook; everything else is kept.
    static func settings(_ settings: [String: Any], installed: Bool) -> [String: Any] {
        var result = settings
        var hooks = result["hooks"] as? [String: Any] ?? [:]
        var groups = stopGroups(in: settings).filter { !isOurs($0) }
        if installed {
            groups.append(["hooks": [["type": "command", "command": command]]])
        }
        hooks["Stop"] = groups.isEmpty ? nil : groups
        result["hooks"] = hooks.isEmpty ? nil : hooks
        return result
    }

    struct InvalidSettings: Error {}

    static func read() throws -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsURL) else { return [:] }
        guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw InvalidSettings() }
        return settings
    }

    static func isInstalled() -> Bool {
        (try? read()).map(isInstalled(in:)) ?? false
    }

    /// Adds or removes the hook in ~/.claude/settings.json; the first change keeps a backup.
    static func setInstalled(_ installed: Bool) throws {
        try write(settings(try read(), installed: installed))
    }

    /// Writes ~/.claude/settings.json; the first change keeps a backup.
    static func write(_ settings: [String: Any]) throws {
        let url = settingsURL
        let backup = url.deletingLastPathComponent().appendingPathComponent("settings.json.wingmate-backup")
        if FileManager.default.fileExists(atPath: url.path), !FileManager.default.fileExists(atPath: backup.path) {
            try FileManager.default.copyItem(at: url, to: backup)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
    }
}

/// Reads a Claude Code transcript for work that is still running in the background (spec CN-3).
enum ClaudeTranscript {
    /// Only the end of the file is read: old, forgotten tasks do not count.
    static let tailLength = 3_000_000

    struct Summary: Sendable {
        let pending: Set<String>
        /// The project most of the recent work was done in.
        let project: String?
        /// The last prompt and the first line of the answer (spec CN-10).
        var task: String?
        var answer: String?
    }

    /// The last prompt typed (tags, commands and tool results left out), on one line, and the
    /// first line of the answer (spec CN-10).
    static func finishedWork(in text: String) -> (task: String?, answer: String?) {
        let prompt = text.split(separator: "\n").reversed().lazy
            .compactMap { ClaudeCodeHistory.message(fromLine: String($0)) }
            .first { $0.role == .user }
        let task = prompt.map { message in
            String(message.text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(220))
        }
        return (task, ClaudeSessionActivity.parse(text).answer)
    }

    static func summary(ofFileAt path: String) -> Summary {
        guard let handle = FileHandle(forReadingAtPath: path) else { return Summary(pending: [], project: nil) }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > UInt64(tailLength) ? size - UInt64(tailLength) : 0)
        let data = (try? handle.readToEnd()) ?? Data()
        let text = wholeLines(in: data, cutAtStart: size > UInt64(tailLength), cutAtEnd: false)
        let project = project(amongPaths: workedPaths(in: String(text.suffix(400_000)))) { path in
            FileManager.default.fileExists(atPath: path + "/.git")
        }
        let work = finishedWork(in: String(text.suffix(400_000)))
        return Summary(pending: pendingTasks(in: text), project: project, task: work.task, answer: work.answer)
    }

    /// The folders the session touched: files it edited or read, and folders it changed into.
    static func workedPaths(in text: String) -> [String] {
        let files = matches(#"file_path\\?"\s*:\s*\\?"(/[^"\\]+)"#, in: text)
        let folders = matches(#"cd (/[A-Za-z0-9_./-]+)"#, in: text)
        return files.map { ($0 as NSString).deletingLastPathComponent } + folders
    }

    /// The name of the repository most of the paths lie in.
    /// - Parameter isRepository: whether a folder is the root of a repository.
    static func project(amongPaths paths: [String], isRepository: (String) -> Bool) -> String? {
        var roots: [String: String?] = [:]
        var counts: [String: Int] = [:]
        for path in paths {
            let root: String?
            if let known = roots[path] {
                root = known
            } else {
                var folder = path
                var found: String?
                while folder.count > 1 {
                    if isRepository(folder) {
                        found = folder
                        break
                    }
                    folder = (folder as NSString).deletingLastPathComponent
                }
                root = found
                roots[path] = found
            }
            if let root { counts[root, default: 0] += 1 }
        }
        let best = counts.max { ($0.value, $1.key) < ($1.value, $0.key) }
        return best.map { ($0.key as NSString).lastPathComponent }
    }

    /// The text of a piece of a file, without the lines the piece cuts in half (a cut may also
    /// fall inside a character, which would make the whole piece unreadable).
    static func wholeLines(in data: Data, cutAtStart: Bool, cutAtEnd: Bool) -> String {
        var piece = data
        if cutAtStart, let newline = piece.firstIndex(of: 0x0A) {
            piece = piece.suffix(from: piece.index(after: newline))
        }
        if cutAtEnd, let newline = piece.lastIndex(of: 0x0A) {
            piece = piece.prefix(upTo: newline)
        }
        return String(bytes: piece, encoding: .utf8) ?? ""
    }

    /// Background tasks that were started and have neither reported back nor been stopped.
    static func pendingTasks(in text: String) -> Set<String> {
        let started = ids(matching: #"running in background with ID: ([A-Za-z0-9_-]+)"#, in: text)
        let reported = ids(matching: #"<task-id>([A-Za-z0-9_-]+)</task-id>"#, in: text)
        let stopped = ids(matching: #"TaskStop[^\n]{0,200}?task_id\\?"\s*:\s*\\?"([A-Za-z0-9_-]+)"#, in: text)
        return started.subtracting(reported).subtracting(stopped)
    }

    private static func ids(matching pattern: String, in text: String) -> Set<String> {
        Set(matches(pattern, in: text))
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }
}
