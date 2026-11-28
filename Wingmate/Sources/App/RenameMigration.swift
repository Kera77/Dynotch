import Foundation
import Security
import ServiceManagement

/// One-time takeover of what the app kept under its old name, Dynotch (spec RN-2…RN-7). This is
/// the only place that still knows the old name.
enum RenameMigration {
    /// v2: 1.9.3 skipped folders whose new name already existed (spec RN-4), so it runs once more.
    static let doneKey = "renameMigration.v2"
    static let oldIdentifier = "com.peterkereki.Dynotch"
    static let oldFolder = "Dynotch"
    static let oldChatFolder = "DynotchChat"
    static let oldKeychainService = "Dynotch Claude account"
    static let oldScheme = "dynotch://"

    /// Runs before anything else reads settings or files; never in the test host.
    static func runIfNeeded(defaults: UserDefaults = .standard) {
        guard !AppInfo.isRunningTests, !defaults.bool(forKey: doneKey) else { return }
        // Marked first: a step that fails must not stop every later launch.
        defaults.set(true, forKey: doneKey)
        let old = defaults.persistentDomain(forName: oldIdentifier) ?? [:]
        let home = FileManager.default.homeDirectoryForCurrentUser
        let movedFiles = moveFolders(home: home)
        guard !old.isEmpty || movedFiles > 0 else { return }
        let copied = copySettings(old, into: defaults)
        defaults.removePersistentDomain(forName: oldIdentifier)
        let keys = moveKeychainItems()
        let hooks = replaceHooks()
        if old["launchAtLoginBeforeRename"] as? Bool == true { try? SMAppService.mainApp.register() }
        removeOldApp(home: home)
        DiagnosticsLog.append("rename", "settings=\(copied) folders=\(movedFiles) keychain=\(keys) hooks=\(hooks)")
    }

    // MARK: - Settings (RN-3)

    static func renamed(_ text: String) -> String {
        [("DyNotch", "Wingmate"), ("Dynotch", "Wingmate"), ("dynotch", "wingmate"), ("DYNOTCH", "WINGMATE")]
            .reduce(text) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
    }

    /// A stored value with the old name replaced in every string, also inside lists, dictionaries
    /// and JSON data. Other data (archives) is kept as it is, as a longer name would break it.
    static func renamed(value: Any) -> Any {
        switch value {
        case let text as String:
            return renamed(text)
        case let list as [Any]:
            return list.map { renamed(value: $0) }
        case let dictionary as [String: Any]:
            return Dictionary(dictionary.map { (renamed($0.key), renamed(value: $0.value)) }) { first, _ in first }
        case let data as Data:
            guard (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) != nil,
                  let text = String(data: data, encoding: .utf8)
            else { return data }
            let result = Data(renamed(text).utf8)
            return (try? JSONSerialization.jsonObject(with: result, options: .fragmentsAllowed)) != nil ? result : data
        default:
            return value
        }
    }

    /// Copies the old settings; a key the new app already has is kept. Returns the number copied.
    static func copySettings(_ old: [String: Any], into defaults: UserDefaults) -> Int {
        var copied = 0
        for (key, value) in old where key != "launchAtLoginBeforeRename" {
            let newKey = renamed(key)
            guard defaults.object(forKey: newKey) == nil else { continue }
            defaults.set(renamed(value: value), forKey: newKey)
            copied += 1
        }
        return copied
    }

    // MARK: - Files (RN-4)

    /// Moves the old folders where the new name expects them. Returns the number moved.
    static func moveFolders(home: URL) -> Int {
        let library = home.appending(path: "Library")
        let newIdentifier = AppInfo.bundleIdentifier
        let moves: [(String, String)] = [
            ("Application Support/\(oldFolder)", "Application Support/Wingmate"),
            ("Logs/\(oldFolder)", "Logs/Wingmate"),
            ("WebKit/\(oldIdentifier)", "WebKit/\(newIdentifier)"),
            ("HTTPStorages/\(oldIdentifier)", "HTTPStorages/\(newIdentifier)"),
            ("HTTPStorages/\(oldIdentifier).binarycookies", "HTTPStorages/\(newIdentifier).binarycookies")
        ]
        var moved = moves.filter { move(library.appending(path: $0.0), to: library.appending(path: $0.1)) }.count
        let support = library.appending(path: "Application Support/Wingmate")
        if move(support.appending(path: oldChatFolder), to: support.appending(path: ClaudeCLI.folderName)) { moved += 1 }
        moved += moveChatHistory(home: home)
        for leftover in ["Caches/\(oldIdentifier)", "Saved Application State/\(oldIdentifier).savedState"] {
            try? FileManager.default.removeItem(at: library.appending(path: leftover))
        }
        return moved
    }

    /// Claude Code keeps the app's chats under a folder named after their working folder, so the
    /// chats can be continued after the rename.
    private static func moveChatHistory(home: URL) -> Int {
        let projects = home.appending(path: ".claude/projects")
        let oldSuffix = "-\(oldFolder)-\(oldChatFolder)"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: projects.path)) ?? []
        return names.filter { name in
            guard name.hasSuffix(oldSuffix) else { return false }
            let newName = String(name.dropLast(oldSuffix.count)) + "-Wingmate-\(ClaudeCLI.folderName)"
            return move(projects.appending(path: name), to: projects.appending(path: newName))
        }.count
    }

    /// Moves `source` to `target`. A target that already exists (the test host or a first run
    /// wrote there) is merged into, the old item winning where both have one; the old folder is
    /// removed only once it is empty.
    static func move(_ source: URL, to target: URL) -> Bool {
        let files = FileManager.default
        guard files.fileExists(atPath: source.path) else { return false }
        var isFolder: ObjCBool = false
        let targetExists = files.fileExists(atPath: target.path, isDirectory: &isFolder)
        var sourceIsFolder: ObjCBool = false
        files.fileExists(atPath: source.path, isDirectory: &sourceIsFolder)
        if targetExists, isFolder.boolValue, sourceIsFolder.boolValue {
            for item in (try? files.contentsOfDirectory(atPath: source.path)) ?? [] {
                _ = move(source.appending(path: item), to: target.appending(path: item))
            }
            if ((try? files.contentsOfDirectory(atPath: source.path)) ?? ["?"]).isEmpty { try? files.removeItem(at: source) }
            return true
        }
        if targetExists { try? files.removeItem(at: target) }
        try? files.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? files.moveItem(at: source, to: target)) != nil
    }

    // MARK: - Keychain (RN-5)

    /// Moves the added Claude accounts to the new service name. Returns the number moved.
    static func moveKeychainItems() -> Int {
        let all: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: oldKeychainService,
            kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(all as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]]
        else { return 0 }
        let accounts = items.compactMap { $0[kSecAttrAccount as String] as? String }
        return accounts.filter(moveKeychainItem).count
    }

    private static func moveKeychainItem(_ account: String) -> Bool {
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: oldKeychainService,
            kSecAttrAccount as String: account
        ]
        var query = match
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data,
              let token = try? JSONDecoder().decode(StoredClaudeToken.self, from: data),
              ClaudeAccountKeychain.write(token, for: account)
        else { return false }
        SecItemDelete(match as CFDictionary)
        return true
    }

    // MARK: - Hooks (RN-6)

    /// The hook events without the old app's hook groups, and the commands taken out.
    static func withoutOldHooks(_ events: [String: Any]) -> (events: [String: Any], removed: [String]) {
        var result = events
        var removed: [String] = []
        for (event, value) in events {
            guard let groups = value as? [[String: Any]] else { continue }
            let kept = groups.filter { group in
                let commands = (group["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String }
                let old = commands.filter { $0.contains(oldScheme) }
                removed += old
                return old.isEmpty
            }
            result[event] = kept.isEmpty ? nil : kept
        }
        return (result, removed)
    }

    /// Replaces the old app's Claude Code and Codex hooks with the same new ones.
    static func replaceHooks() -> Int {
        var replaced = 0
        if var settings = try? ClaudeHook.read(), let events = settings["hooks"] as? [String: Any] {
            let (kept, removed) = withoutOldHooks(events)
            if !removed.isEmpty {
                settings["hooks"] = kept.isEmpty ? nil : kept
                try? ClaudeHook.write(settings)
                if removed.contains(where: { $0.contains("claude-finished") }) { try? ClaudeHook.setInstalled(true) }
                if removed.contains(where: { !$0.contains("claude-finished") }) { try? ClaudeQuestionHook.setInstalled(true) }
                replaced += removed.count
            }
        }
        if var codex = try? CodexHook.read(), let events = codex["hooks"] as? [String: Any] {
            let (kept, removed) = withoutOldHooks(events)
            if !removed.isEmpty {
                codex["hooks"] = kept
                let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                if let data = try? JSONSerialization.data(withJSONObject: codex, options: options) {
                    try? data.write(to: CodexHook.hooksURL, options: .atomic)
                }
                try? CodexHook.setInstalled(true)
                replaced += removed.count
            }
        }
        return replaced
    }

    // MARK: - Old app (RN-7)

    /// Moves the old app to the Bin if it is still installed.
    private static func removeOldApp(home: URL) {
        for folder in [URL(fileURLWithPath: "/Applications"), home.appending(path: "Applications")] {
            let app = folder.appending(path: "\(oldFolder).app")
            guard Bundle(url: app)?.bundleIdentifier == oldIdentifier else { continue }
            try? FileManager.default.trashItem(at: app, resultingItemURL: nil)
        }
    }
}
