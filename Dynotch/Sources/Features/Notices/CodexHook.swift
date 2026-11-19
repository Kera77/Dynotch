import Foundation

/// The Codex (ChatGPT app or terminal) tells Dynotch that it finished a turn through a "Stop"
/// hook in ~/.codex/hooks.json that opens a dynotch:// link (spec CN-8). Codex runs hooks only
/// with its `codex_hooks` feature on, which is set in ~/.codex/config.toml.
enum CodexHook {
    static let marker = "dynotch://codex-finished"
    /// Dynotch's own Codex runs are skipped; the project is the session's folder, from the hook's
    /// input when it names one; the app it runs in comes from `__CFBundleIdentifier`.
    static let command = #"[ -n "$DYNOTCH_CHAT" ] && exit 0; j=$(cat); "#
        + #"c=$(printf '%s' "$j" | /usr/bin/sed -n 's/.*"cwd" *: *"\([^"]*\)".*/\1/p' | head -1); [ -z "$c" ] && c="$PWD"; "#
        + #"open -g "dynotch://codex-finished?project=$(basename "$c" | sed 's/ /%20/g')&app=${__CFBundleIdentifier:-}""#

    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }

    static var hooksURL: URL { folder.appendingPathComponent("hooks.json") }
    static var configURL: URL { folder.appendingPathComponent("config.toml") }

    static func notice(from url: URL, now: Date) -> StickyNotice? {
        guard url.scheme?.lowercased() == "dynotch", url.host?.lowercased() == "codex-finished" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let project = items.first { $0.name == "project" }?.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Dynotch's own chat runs in its own folder; it reports its answers itself.
        guard project != ClaudeCLI.folderName else { return nil }
        let app = items.first { $0.name == "app" }?.value.flatMap { $0.isEmpty ? nil : $0 } ?? "com.openai.codex"
        return StickyNotice(
            title: "ChatGPT finished", detail: String(project.prefix(60)), date: now, appIdentifier: app, iconApp: "com.openai.codex"
        )
    }

    // MARK: - hooks.json

    private static func isOurs(_ group: [String: Any]) -> Bool {
        (group["hooks"] as? [[String: Any]] ?? []).contains { ($0["command"] as? String ?? "").contains(marker) }
    }

    private static func stopGroups(in hooks: [String: Any]) -> [[String: Any]] {
        ((hooks["hooks"] as? [String: Any])?["Stop"] as? [[String: Any]]) ?? []
    }

    static func isInstalled(in hooks: [String: Any]) -> Bool {
        stopGroups(in: hooks).contains(where: isOurs)
    }

    /// The hooks file with (or without) Dynotch's Stop hook; other apps' hooks are kept.
    static func hooks(_ hooks: [String: Any], installed: Bool) -> [String: Any] {
        var result = hooks
        var events = result["hooks"] as? [String: Any] ?? [:]
        var groups = stopGroups(in: hooks).filter { !isOurs($0) }
        if installed { groups.append(["hooks": [["type": "command", "command": command]]]) }
        events["Stop"] = groups.isEmpty ? nil : groups
        result["hooks"] = events
        return result
    }

    /// config.toml with Codex's hooks feature on; unchanged if it already is.
    static func configWithHooksOn(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        let isOn = lines.contains { line in
            let bare = line.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
            let parts = bare.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            return parts.count == 2 && parts[0] == "codex_hooks" && parts[1] == "true"
        }
        guard !isOn else { return text }
        let setting = "codex_hooks = true  # dynotch"
        var result = lines.filter { line in
            !(line.trimmingCharacters(in: .whitespaces).hasPrefix("codex_hooks") && line.contains("="))
        }
        if let features = result.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "[features]" }) {
            result.insert(setting, at: features + 1)
            return result.joined(separator: "\n")
        }
        let body = result.joined(separator: "\n")
        return setting + "\n" + (body.isEmpty ? "" : "\n" + body)
    }

    static func read() throws -> [String: Any] {
        guard let data = try? Data(contentsOf: hooksURL) else { return [:] }
        guard let hooks = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ClaudeHook.InvalidSettings() }
        return hooks
    }

    static func isInstalled() -> Bool {
        (try? read()).map(isInstalled(in:)) ?? false
    }

    /// Adds or removes the hook; the first change of each file keeps a backup.
    static func setInstalled(_ installed: Bool) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: hooks(try read(), installed: installed), options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try backUp(hooksURL)
        try data.write(to: hooksURL, options: .atomic)
        guard installed else { return }
        let config = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let updated = configWithHooksOn(config)
        guard updated != config else { return }
        try backUp(configURL)
        try updated.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private static func backUp(_ url: URL) throws {
        let backup = url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".dynotch-backup")
        if FileManager.default.fileExists(atPath: url.path), !FileManager.default.fileExists(atPath: backup.path) {
            try FileManager.default.copyItem(at: url, to: backup)
        }
    }
}
