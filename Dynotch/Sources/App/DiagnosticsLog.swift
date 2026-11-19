import Foundation

/// Small log files in ~/Library/Logs/Dynotch, for troubleshooting. Writes run one at a time on a
/// background queue, so callers on any thread never wait for the disk and no line is lost.
enum DiagnosticsLog {
    private static let queue = DispatchQueue(label: "Dynotch.DiagnosticsLog", qos: .utility)
    /// The lines of each appended log, read from disk once; only touched on `queue`.
    nonisolated(unsafe) private static var cache: [String: [String]] = [:]

    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Dynotch")
    }

    /// Replaces the log's text.
    static func write(_ name: String, _ text: String) {
        let stamped = "\(Date().formatted(.iso8601)) Dynotch \(AppInfo.version) (\(AppInfo.build))\n\(text)\n"
        queue.async {
            cache[name] = nil
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? stamped.write(to: directory.appendingPathComponent("\(name).log"), atomically: true, encoding: .utf8)
        }
    }

    /// Adds a line, keeping the last `limit` lines.
    static func append(_ name: String, _ line: String, limit: Int = 200) {
        let stamped = "\(Date().formatted(.iso8601)) \(line)"
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

extension DiagnosticsLog {
    /// Everything useful for troubleshooting, without any content: versions, modules, permissions
    /// and the end of each log (spec C-7).
    static func report(enabledModules: [String], permissions: [String: Bool]) -> String {
        var lines = [
            "Dynotch \(AppInfo.version) (\(AppInfo.build)) on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Modules: " + enabledModules.joined(separator: ", "),
            "Permissions: " + permissions.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value ? "yes" : "no")" }.joined(separator: ", ")
        ]
        flush()
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasSuffix(".log") }.sorted()
        for name in files {
            let text = (try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)) ?? ""
            let tail = text.split(separator: "\n").suffix(15).joined(separator: "\n")
            lines.append("\n== \(name)\n\(tail)")
        }
        return lines.joined(separator: "\n")
    }
}
