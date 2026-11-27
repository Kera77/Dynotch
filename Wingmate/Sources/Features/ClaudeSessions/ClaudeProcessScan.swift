import Darwin
import Foundation

/// The Claude Code processes running on this Mac, each with the app it runs in, so sessions
/// that sent no hook event yet are listed too (spec CS-9).
enum ClaudeProcessScan {
    struct Found: Equatable, Sendable {
        let pid: pid_t
        /// The host app's bundle identifier; nil e.g. under tmux.
        let app: String?
        let folder: String
        let started: Date
    }

    /// Every Claude Code process, except the ones Wingmate itself runs (its chat).
    nonisolated static func running(ownApp: String? = Bundle.main.bundleIdentifier) -> [Found] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(count) + 32)
        let listed = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        var found: [Found] = []
        for pid in pids.prefix(Int(max(listed, 0))) where pid > 1 {
            guard let path = executable(of: pid), isClaude(path: path),
                  let info = bsdInfo(of: pid),
                  // A helper started by a Claude process is part of that session.
                  !(executable(of: pid_t(info.pbi_ppid)).map(isClaude(path:)) ?? false),
                  let folder = TerminalProcessInfo.directory(pid: pid),
                  !folder.hasSuffix(ClaudeCLI.folderName)
            else { continue }
            let app = hostApp(above: pid_t(info.pbi_ppid))
            if let ownApp, app == ownApp { continue }
            let started = Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec))
            found.append(Found(pid: pid, app: app, folder: folder, started: started))
        }
        return found
    }

    /// The CLI (`claude`, `~/.local/share/claude/versions/2.x`) or the Claude app's built-in copy.
    nonisolated static func isClaude(path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        return name == "claude" || path.contains("/.local/share/claude/versions/")
    }

    /// The outermost `.app` in a path: a helper inside an app's Frameworks counts as the app.
    nonisolated static func outermostApp(in path: String) -> String? {
        let slashed = path + "/"
        guard let range = slashed.range(of: ".app/") else { return nil }
        return String(slashed[..<range.lowerBound]) + ".app"
    }

    /// A helper's or an embedded tool's identifier as the app's own (spec CS-9).
    nonisolated static func hostBundleID(_ id: String) -> String {
        if id == "com.anthropic.claude-code" || id.hasPrefix("com.anthropic.claudefordesktop") {
            return "com.anthropic.claudefordesktop"
        }
        if let range = id.range(of: ".helper", options: .caseInsensitive) { return String(id[..<range.lowerBound]) }
        return id
    }

    // MARK: - Private

    /// The first parent that lives in an app bundle (Terminal, VS Code, Claude…).
    private nonisolated static func hostApp(above parent: pid_t) -> String? {
        var pid = parent
        for _ in 0..<24 where pid > 1 {
            if let path = executable(of: pid), let app = outermostApp(in: path),
               let id = Bundle(path: app)?.bundleIdentifier {
                return hostBundleID(id)
            }
            guard let info = bsdInfo(of: pid) else { return nil }
            pid = pid_t(info.pbi_ppid)
        }
        return nil
    }

    private nonisolated static func executable(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    private nonisolated static func bsdInfo(of pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        return proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size ? info : nil
    }
}
