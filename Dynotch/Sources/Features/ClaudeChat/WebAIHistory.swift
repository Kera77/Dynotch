import Foundation
import SQLite3

/// A conversation on claude.ai or chatgpt.com, found in a browser's history (spec AI-17).
struct WebAIConversation: Identifiable, Hashable, Sendable {
    let url: URL
    let title: String
    let provider: AIProvider
    let visited: Date

    var id: String { url.absoluteString }
}

/// The claude.ai and chatgpt.com conversations the owner opened in a browser, read from the
/// browsers' local history files (Chromium-based browsers, Zen and Firefox, Safari). Only the
/// address and the page title are read; nothing leaves the Mac. The history files of the
/// Chromium browsers and Safari need Full Disk Access, which the notifications need anyway.
enum WebAIHistory {
    private static let limit = 300

    /// Newest first, one row per conversation.
    static func conversations() -> [WebAIConversation] {
        var found: [WebAIConversation] = []
        for file in chromiumFiles() {
            found += read(file, sql: chromiumSQL) { Date(timeIntervalSince1970: $0 / 1_000_000 - 11_644_473_600) }
        }
        for file in firefoxFiles() {
            found += read(file, sql: firefoxSQL) { Date(timeIntervalSince1970: $0 / 1_000_000) }
        }
        let safari = home.appendingPathComponent("Library/Safari/History.db")
        found += read(safari, sql: safariSQL) { Date(timeIntervalSinceReferenceDate: $0) }
        return merged(found)
    }

    /// One row per address (its newest visit), newest first.
    static func merged(_ rows: [WebAIConversation]) -> [WebAIConversation] {
        var best: [String: WebAIConversation] = [:]
        for row in rows {
            if let current = best[row.id], current.visited >= row.visited { continue }
            best[row.id] = row
        }
        return best.values.sorted { $0.visited > $1.visited }
    }

    /// A conversation from an address and a page title; nil for anything else or an untitled page.
    static func conversation(url text: String, title rawTitle: String, visited: Date) -> WebAIConversation? {
        guard var components = URLComponents(string: text) else { return nil }
        components.query = nil
        components.fragment = nil
        guard let url = components.url, let host = url.host else { return nil }
        let path = url.path
        let provider: AIProvider
        if host == "claude.ai", path.hasPrefix("/chat/") {
            provider = .claude
        } else if host == "chatgpt.com", path.hasPrefix("/c/"), !path.hasPrefix("/c/local-") {
            provider = .chatgpt
        } else {
            return nil
        }
        let title = cleaned(rawTitle)
        guard !title.isEmpty else { return nil }
        return WebAIConversation(url: url, title: title, provider: provider, visited: visited)
    }

    /// "Plan a trip - Claude" → "Plan a trip"; the sites' own names and "New chat" are no title.
    static func cleaned(_ title: String) -> String {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in [" - Claude", " | Claude", " – Claude", " - ChatGPT", " | ChatGPT"] where text.hasSuffix(suffix) {
            text = String(text.dropLast(suffix.count))
        }
        if text.hasPrefix("ChatGPT - ") { text = String(text.dropFirst("ChatGPT - ".count)) }
        let generic = ["claude", "chatgpt", "new chat", "új csevegés"]
        return generic.contains(text.lowercased()) ? "" : text
    }

    // MARK: - Files

    private static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    /// Every profile's History file of the Chromium-based browsers (Chrome, Arc, Dia, Comet,
    /// Edge, Brave, Vivaldi, Opera, Ardia…).
    private static func chromiumFiles() -> [URL] {
        let support = home.appendingPathComponent("Library/Application Support")
        return files(named: "History", under: support, depth: 4)
            .filter { !$0.path.contains("/zen/") && !$0.path.contains("/Firefox/") }
    }

    private static func firefoxFiles() -> [URL] {
        let support = home.appendingPathComponent("Library/Application Support")
        return ["zen/Profiles", "Firefox/Profiles"].flatMap { folder in
            files(named: "places.sqlite", under: support.appendingPathComponent(folder), depth: 1)
        }
    }

    private static func files(named name: String, under root: URL, depth: Int) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var result: [URL] = []
        let baseDepth = root.pathComponents.count
        for case let url as URL in enumerator {
            let level = url.pathComponents.count - baseDepth
            if level > depth + 1 {
                enumerator.skipDescendants()
                continue
            }
            if url.lastPathComponent == name { result.append(url) }
        }
        return result
    }

    // MARK: - Reading

    private static let pattern = "(url LIKE 'https://claude.ai/chat/%' OR url LIKE 'https://chatgpt.com/c/%')"
    private static let chromiumSQL = """
        SELECT url, title, last_visit_time FROM urls WHERE \(pattern) ORDER BY last_visit_time DESC LIMIT \(limit)
        """
    private static let firefoxSQL = """
        SELECT url, IFNULL(title, ''), IFNULL(last_visit_date, 0) FROM moz_places WHERE \(pattern)
        ORDER BY last_visit_date DESC LIMIT \(limit)
        """
    private static let safariSQL = """
        SELECT i.url, IFNULL(v.title, ''), MAX(v.visit_time) FROM history_items i JOIN history_visits v ON v.history_item = i.id
        WHERE (i.url LIKE 'https://claude.ai/chat/%' OR i.url LIKE 'https://chatgpt.com/c/%') GROUP BY i.url LIMIT \(limit)
        """

    /// The browser keeps its file locked and half in a write-ahead log: a copy is read.
    private static func read(_ file: URL, sql: String, date: (Double) -> Date) -> [WebAIConversation] {
        guard FileManager.default.isReadableFile(atPath: file.path) else { return [] }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("dynotch-webai-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        guard (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else { return [] }
        let copy = folder.appendingPathComponent("history.db")
        guard (try? FileManager.default.copyItem(at: file, to: copy)) != nil else { return [] }
        for suffix in ["-wal", "-shm"] {
            try? FileManager.default.copyItem(at: URL(fileURLWithPath: file.path + suffix), to: URL(fileURLWithPath: copy.path + suffix))
        }
        var handle: OpaquePointer?
        guard sqlite3_open_v2(copy.path, &handle, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let handle else {
            sqlite3_close(handle)
            return []
        }
        defer { sqlite3_close(handle) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return [] }
        defer { sqlite3_finalize(statement) }
        var rows: [WebAIConversation] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let url = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? ""
            let title = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
            if let row = conversation(url: url, title: title, visited: date(sqlite3_column_double(statement, 2))) { rows.append(row) }
        }
        return rows
    }
}
