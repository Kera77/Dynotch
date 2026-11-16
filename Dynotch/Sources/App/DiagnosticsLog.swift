import Foundation

/// Small log files in ~/Library/Logs/Dynotch, for troubleshooting. Each write replaces the file.
enum DiagnosticsLog {
    private static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Dynotch")
    }

    static func write(_ name: String, _ text: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamped = "\(Date().formatted(.iso8601)) Dynotch \(AppInfo.version) (\(AppInfo.build))\n\(text)\n"
        try? stamped.write(to: directory.appendingPathComponent("\(name).log"), atomically: true, encoding: .utf8)
    }

    /// Adds a line, keeping the last `limit` lines.
    static func append(_ name: String, _ line: String, limit: Int = 200) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).log")
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var lines = existing.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        lines.append("\(Date().formatted(.iso8601)) \(line)")
        try? (lines.suffix(limit).joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
