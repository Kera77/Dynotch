import Foundation

/// Small log files in ~/Library/Logs/Dynotch, for troubleshooting. Each write replaces the file.
enum DiagnosticsLog {
    static var directory: URL {
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

extension DiagnosticsLog {
    /// Everything useful for troubleshooting, without any content: versions, modules, permissions
    /// and the end of each log (spec C-7).
    static func report(enabledModules: [String], permissions: [String: Bool]) -> String {
        var lines = [
            "Dynotch \(AppInfo.version) (\(AppInfo.build)) on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Modules: " + enabledModules.joined(separator: ", "),
            "Permissions: " + permissions.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value ? "yes" : "no")" }.joined(separator: ", ")
        ]
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
