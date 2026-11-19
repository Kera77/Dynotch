import Foundation

/// Runs a command-line tool and collects what it prints, with a time limit: a tool that hangs
/// (Notes waiting on a prompt, a stuck `system_profiler`) is stopped instead of blocking its
/// caller for good.
enum ProcessRunner {
    struct Result: Sendable {
        let status: Int32
        let output: Data
        let errors: Data
        let timedOut: Bool

        var succeeded: Bool { status == 0 && !timedOut }
        var errorText: String {
            (String(bytes: errors, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Blocks the calling thread until the tool ends or the time is up: never call it on the
    /// main thread. Nil when the tool could not be started.
    static func run(
        _ path: String, _ arguments: [String], timeout: TimeInterval = 20, environment: [String: String]? = nil
    ) -> Result? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        if let environment { process.environment = environment }
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        let ended = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in ended.signal() }
        do {
            try process.run()
        } catch {
            return nil
        }
        // Both outputs are read at once, so a full pipe never stalls the tool.
        let outputBox = DataBox()
        let errorBox = DataBox()
        let reading = DispatchGroup()
        read(output.fileHandleForReading, into: outputBox, group: reading)
        read(errors.fileHandleForReading, into: errorBox, group: reading)
        var timedOut = false
        if ended.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            process.terminate()
            if ended.wait(timeout: .now() + 2) == .timedOut { kill(process.processIdentifier, SIGKILL) }
        }
        _ = reading.wait(timeout: .now() + 2)
        return Result(
            status: process.isRunning ? -1 : process.terminationStatus,
            output: outputBox.data, errors: errorBox.data, timedOut: timedOut
        )
    }

    private static func read(_ handle: FileHandle, into box: DataBox, group: DispatchGroup) {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            box.data = handle.readDataToEndOfFile()
            group.leave()
        }
    }
}

/// Bytes handed from a reading thread to the waiting one.
private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = Data()

    var data: Data {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
