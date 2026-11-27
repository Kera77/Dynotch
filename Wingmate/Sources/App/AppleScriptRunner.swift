import AppKit

/// The one place AppleScript runs (spec RF-18): in process on the caller's own serial queue (never
/// on the main thread), or out of process through `osascript` with a time limit. Values go in as
/// arguments or quoted with `quotedString(_:)`, never pasted into the source as they are.
enum AppleScriptRunner {
    private static let sharedQueue = DispatchQueue(label: "wingmate.applescript", qos: .userInitiated)

    /// Runs `source` on `queue`; `read` turns the result into a value there. Nil when it failed;
    /// the error number goes to the `log` file.
    static func run<Value: Sendable>(
        _ source: String, on queue: DispatchQueue? = nil, log: String, what: String,
        read: @escaping @Sendable (NSAppleEventDescriptor) -> Value
    ) async -> Value? {
        await withCheckedContinuation { continuation in
            (queue ?? sharedQueue).async {
                var error: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
                if let error {
                    let code = error[NSAppleScript.errorNumber] as? Int ?? 0
                    DiagnosticsLog.append(log, "\(what) failed (\(code))")
                }
                continuation.resume(returning: result.map(read))
            }
        }
    }

    /// `osascript` with the script's own `argv`; JavaScript for Automation when `javaScript`.
    nonisolated static func osascript(
        _ script: String, javaScript: Bool = false, arguments: [String] = [], timeout: TimeInterval
    ) -> ProcessRunner.Result? {
        let language = javaScript ? ["-l", "JavaScript"] : []
        return ProcessRunner.run("/usr/bin/osascript", language + ["-e", script] + arguments, timeout: timeout)
    }

    /// An AppleScript string literal of `text`: backslashes and quotes escaped (spec RF-6).
    nonisolated static func quotedString(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// A shell word: in single quotes, which stop every expansion (spec RF-6).
    nonisolated static func shellQuoted(_ word: String) -> String {
        "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// The Terminal script that runs `words` (each one shell-quoted) in a new window.
    nonisolated static func terminalScript(running words: [String], in folder: String? = nil) -> String {
        let command = words.map(shellQuoted).joined(separator: " ")
        let line = folder.map { "cd \(shellQuoted($0)) && \(command)" } ?? command
        return "tell application \"Terminal\"\nactivate\ndo script \(quotedString(line))\nend tell"
    }

    /// Opens Terminal and runs the command there (spec AI-12, AI-15).
    static func runInTerminal(_ words: [String], in folder: String? = nil) {
        let source = terminalScript(running: words, in: folder)
        Task { _ = await run(source, log: "ai", what: "Terminal") { _ in true } }
    }
}
