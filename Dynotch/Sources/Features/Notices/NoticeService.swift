import Foundation
import Observation

/// A message that stays under the closed notch until it is swiped away (spec CN-1).
struct StickyNotice: Equatable, Sendable {
    let title: String
    let detail: String
    let date: Date
    /// Hovering it opens the Claude chat (spec CC-5).
    var opensChat = false
    /// Claude Code waits for an answer: the notice goes when it is answered (spec CQ-1).
    var isQuestion = false
    /// The app Claude Code runs in (Terminal, VS Code…), brought forward on hover (spec CQ-3).
    var appIdentifier: String?
    /// An SF Symbol instead of Claude's mark, e.g. for Dynotch's own update (spec U-5).
    var symbol: String?
    /// An app's icon instead of Claude's mark, e.g. ChatGPT's (spec CN-8).
    var iconApp: String?
    /// Who it is from, when the icon does not tell (e.g. the chat's service).
    var sourceName: String?
    /// A finished download: a download icon and a green tick, gone after 3 s (spec PV-57).
    var download: URL?
    /// A click opens this module, e.g. the Tools after a timer (spec TM-5, WX-7).
    var opens: FeatureID?
    /// Goes by itself after this many seconds (spec TM-5, WX-7).
    var stays: TimeInterval?

    /// A download in `~/Downloads` finished (spec PV-57).
    static func downloaded(_ file: URL) -> StickyNotice {
        StickyNotice(
            title: "Downloaded", detail: String(file.lastPathComponent.prefix(60)), date: Date(),
            symbol: "arrow.down.circle.fill", sourceName: "Downloads", download: file
        )
    }

    /// The chat in the notch answered (spec CC-5).
    static func answered(by service: String, in chat: String) -> StickyNotice {
        StickyNotice(title: "\(service) answered", detail: chat, date: Date(), opensChat: true, sourceName: service)
    }

    /// Who it is from, written beside its icon in the Wings (spec PV-37).
    var source: String {
        if let sourceName { return sourceName }
        if symbol != nil { return "Wingmate" }
        if iconApp == "com.openai.codex" { return "ChatGPT" }
        return "Claude"
    }
}

@MainActor
@Observable
final class NoticeService {
    private(set) var notice: StickyNotice?

    @ObservationIgnored private var downloadExpiry: Task<Void, Never>?
    @ObservationIgnored private var expiry: Task<Void, Never>?
    /// How long a finished download stays (spec PV-57).
    static let downloadStays: TimeInterval = 3

    func show(_ notice: StickyNotice) {
        // Nothing pops up during the tour (spec OB-11).
        guard !OnboardingController.isRunning else { return }
        self.notice = notice
        expiry?.cancel()
        guard let stays = notice.stays else { return }
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(stays))
            guard !Task.isCancelled, let self, self.notice == notice else { return }
            self.notice = nil
        }
    }

    /// A finished download, unless something more important stands there; it goes by itself.
    func showDownload(_ file: URL) {
        if let notice, notice.download == nil { return }
        let shown = StickyNotice.downloaded(file)
        notice = shown
        RecentNotice.shared.note(.tray, file: file, id: "download:" + file.path)
        downloadExpiry?.cancel()
        downloadExpiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.downloadStays))
            guard !Task.isCancelled, let self, self.notice == shown else { return }
            self.notice = nil
        }
    }

    func dismiss() {
        if notice != nil { notice = nil }
    }

    /// Links other programs open to tell Dynotch something (spec CN-2).
    func handle(_ url: URL) {
        switch ClaudeQuestionHook.event(from: url, now: Date()) {
        case .asks(let question):
            show(question)
            return
        case .answered:
            if notice?.isQuestion == true { dismiss() }
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
                self?.show(StickyNotice(title: notice.title, detail: project, date: notice.date, appIdentifier: notice.appIdentifier))
            } else {
                DiagnosticsLog.append("claude-hook", "stopped with \(pending.count) background task(s) running: no notice")
            }
        }
    }
}

/// Claude Code tells Dynotch that it finished a task through a "Stop" hook that opens a
/// dynotch:// link (spec CN-2).
enum ClaudeHook {
    static let marker = "dynotch://claude-finished"
    /// Opens the link in the background, with the project folder's name.
    /// Dynotch's own chat runs are skipped; the hook's input (which names the transcript) is kept
    /// in a temporary file whose name travels in the link.
    static let command = #"[ -n "$DYNOTCH_CHAT" ] && exit 0; f=$(mktemp "${TMPDIR:-/tmp}/dynotch-stop.XXXXXX") && cat > "$f"; "#
        + #"open -g "dynotch://claude-finished?project=$(basename "$PWD" | sed 's/ /%20/g')&info=$(basename "$f")"#
        + #"&app=${__CFBundleIdentifier:-}""#

    /// The transcript of the session that stopped, from the hook's input file (which is removed).
    static func transcriptPath(from url: URL) -> String? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let name = items.first(where: { $0.name == "info" })?.value,
              name.hasPrefix("dynotch-stop."), !name.contains("/")
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
        guard url.scheme?.lowercased() == "dynotch", url.host?.lowercased() == "claude-finished" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let project = items.first { $0.name == "project" }?.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Dynotch's own chat runs through Claude Code too; it reports its answers itself.
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

    /// The settings with (or without) Dynotch's Stop hook; everything else is kept.
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
        let backup = url.deletingLastPathComponent().appendingPathComponent("settings.json.dynotch-backup")
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
        return Summary(pending: pendingTasks(in: text), project: project)
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
