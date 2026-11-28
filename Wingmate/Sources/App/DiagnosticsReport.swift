import Foundation

extension DiagnosticsLog {
    /// Everything useful for troubleshooting, without any content: versions, modules, permissions
    /// and the end of each log (spec C-7).
    static func report(enabledModules: [String], permissions: [String: Bool]) -> String {
        var lines = [
            "Wingmate \(AppInfo.version) (\(AppInfo.build)) on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Modules: " + enabledModules.joined(separator: ", "),
            "Tour: " + (UserDefaults.standard.bool(forKey: OnboardingProgress.completedKey) ? "done" : "not done"),
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
