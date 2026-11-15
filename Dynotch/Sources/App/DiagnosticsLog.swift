import Foundation

/// Small log files in ~/Library/Logs/Dynotch, for troubleshooting. Each write replaces the file.
enum DiagnosticsLog {
    static func write(_ name: String, _ text: String) {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Dynotch")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamped = "\(Date().formatted(.iso8601)) Dynotch \(AppInfo.version) (\(AppInfo.build))\n\(text)\n"
        try? stamped.write(to: directory.appendingPathComponent("\(name).log"), atomically: true, encoding: .utf8)
    }
}
