import Foundation

/// Small log files in ~/Library/Logs/Wingmate, for troubleshooting. Writes run one at a time on a
/// background queue, so callers on any thread never wait for the disk and no line is lost.
enum DiagnosticsLog {
    private static let queue = DispatchQueue(label: "Wingmate.DiagnosticsLog", qos: .utility)
    /// The lines of each appended log, read from disk once; only touched on `queue`.
    nonisolated(unsafe) private static var cache: [String: [String]] = [:]

    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Wingmate")
    }

    /// The home folder as "~", so the user name stays out of the logs.
    nonisolated static func scrubbed(_ text: String, home: String = NSHomeDirectory()) -> String {
        home.count > 1 ? text.replacingOccurrences(of: home, with: "~") : text
    }

    /// Replaces the log's text.
    static func write(_ name: String, _ text: String) {
        let stamped = "\(Date().formatted(.iso8601)) Wingmate \(AppInfo.version) (\(AppInfo.build))\n\(scrubbed(text))\n"
        queue.async {
            cache[name] = nil
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? stamped.write(to: directory.appendingPathComponent("\(name).log"), atomically: true, encoding: .utf8)
        }
    }

    /// Adds a line, keeping the last `limit` lines.
    static func append(_ name: String, _ line: String, limit: Int = 200) {
        let stamped = "\(Date().formatted(.iso8601)) \(scrubbed(line))"
        queue.async {
            let url = directory.appendingPathComponent("\(name).log")
            var lines = cache[name] ?? {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                return existing.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            }()
            lines.append(stamped)
            lines = Array(lines.suffix(limit))
            cache[name] = lines
            try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// Waits until the lines handed over so far are on disk.
    static func flush() {
        queue.sync {}
    }
}
