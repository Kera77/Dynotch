import Combine
import Foundation

/// A message that stays under the closed notch until it is swiped away (spec CN-1).
struct StickyNotice: Equatable, Sendable {
    let title: String
    let detail: String
    let date: Date
    /// Hovering it opens the Claude chat (spec CC-5).
    var opensChat = false
}

@MainActor
final class NoticeService: ObservableObject {
    @Published private(set) var notice: StickyNotice?

    func show(_ notice: StickyNotice) {
        self.notice = notice
    }

    func dismiss() {
        if notice != nil { notice = nil }
    }

    /// Links other programs open to tell Dynotch something (spec CN-2).
    func handle(_ url: URL) {
        if let notice = ClaudeHook.notice(from: url, now: Date()) { show(notice) }
    }
}

/// Claude Code tells Dynotch that it finished a task through a "Stop" hook that opens a
/// dynotch:// link (spec CN-2).
enum ClaudeHook {
    static let marker = "dynotch://claude-finished"
    /// Opens the link in the background, with the project folder's name.
    static let command = #"open -g "dynotch://claude-finished?project=$(basename "$PWD" | sed 's/ /%20/g')""#

    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    static func notice(from url: URL, now: Date) -> StickyNotice? {
        guard url.scheme?.lowercased() == "dynotch", url.host?.lowercased() == "claude-finished" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let project = items.first { $0.name == "project" }?.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Dynotch's own chat runs through Claude Code too; it reports its answers itself.
        guard project != ClaudeCLI.folderName else { return nil }
        return StickyNotice(title: "Claude finished", detail: String(project.prefix(60)), date: now)
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

    private static func read() throws -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsURL) else { return [:] }
        guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw InvalidSettings() }
        return settings
    }

    static func isInstalled() -> Bool {
        (try? read()).map(isInstalled(in:)) ?? false
    }

    /// Adds or removes the hook in ~/.claude/settings.json; the first change keeps a backup.
    static func setInstalled(_ installed: Bool) throws {
        let current = try read()
        let url = settingsURL
        let backup = url.deletingLastPathComponent().appendingPathComponent("settings.json.dynotch-backup")
        if FileManager.default.fileExists(atPath: url.path), !FileManager.default.fileExists(atPath: backup.path) {
            try FileManager.default.copyItem(at: url, to: backup)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: settings(current, installed: installed), options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: url, options: .atomic)
    }
}
