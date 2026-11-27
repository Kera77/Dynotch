import AppKit
import Darwin
import SwiftTerm

/// One shell in the Terminal module: the user's login shell in their home folder, as in
/// Terminal (spec TE-1).
@MainActor
final class TerminalSession: NSObject, Identifiable {
    let id = UUID()
    let view: NotchTerminalView
    /// A key went into the shell (spec TE-9).
    var onInput: (() -> Void)? {
        didSet { view.onInput = onInput }
    }

    private let onEnd: (TerminalSession, Int32?) -> Void
    private var isEnded = false

    init(fontSize: CGFloat, onEnd: @escaping (TerminalSession, Int32?) -> Void) {
        self.onEnd = onEnd
        view = NotchTerminalView(frame: NSRect(x: 0, y: 0, width: 640, height: 300))
        super.init()
        view.getTerminal().changeHistorySize(NotchTerminalView.scrollback)
        view.processDelegate = self
        view.configure(fontSize: fontSize)
        start()
    }

    private func start() {
        let shell = Self.loginShell
        let name = (shell as NSString).lastPathComponent
        var environment = Terminal.getEnvironmentVariables(termName: "xterm-256color", trueColor: true)
        // The login shell's path_helper builds the rest of PATH, as in Terminal.
        environment += ["SHELL=\(shell)", "PATH=/usr/bin:/bin:/usr/sbin:/sbin", "TERM_PROGRAM=Wingmate"]
        if let tmp = ProcessInfo.processInfo.environment["TMPDIR"] { environment.append("TMPDIR=\(tmp)") }
        // A leading "-" in argv[0] makes it a login shell.
        view.startProcess(executable: shell, args: [], environment: environment, execName: "-\(name)",
                          currentDirectory: NSHomeDirectory())
    }

    func terminate() {
        guard !isEnded else { return }
        isEnded = true
        view.terminate()
    }

    func setFontSize(_ size: CGFloat) {
        view.configure(fontSize: size)
    }

    // MARK: - What the tab shows (spec TE-4, TE-6)

    /// The program in front (e.g. "vim"), else the folder's name.
    var title: String {
        let shellName = (Self.loginShell as NSString).lastPathComponent
        if let program = TerminalProcessInfo.foregroundName(descriptor: view.process.childfd), program != shellName,
           !program.hasPrefix("-") {
            return program
        }
        guard let folder = directory else { return shellName }
        return folder == NSHomeDirectory() ? "~" : (folder as NSString).lastPathComponent
    }

    /// The shell's working folder.
    var directory: String? {
        let pid = view.process.shellPid
        return pid > 0 ? TerminalProcessInfo.directory(pid: pid) : nil
    }

    /// The user's login shell, as Terminal starts it.
    static var loginShell: String {
        if let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell {
            let path = String(cString: shell)
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        return "/bin/zsh"
    }
}

// SwiftTerm calls these on the main queue.
extension TerminalSession: @preconcurrency LocalProcessTerminalViewDelegate {
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        isEnded = true
        onEnd(self, exitCode)
    }
}

/// The foreground program and the working folder of a shell, from the kernel (spec TE-4, TE-6).
enum TerminalProcessInfo {
    static func foregroundName(descriptor: Int32) -> String? {
        guard descriptor >= 0 else { return nil }
        let group = tcgetpgrp(descriptor)
        guard group > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(group, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let name = String(cString: buffer)
        return name.isEmpty ? nil : name
    }

    static func directory(pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { raw in
            raw.bindMemory(to: CChar.self).baseAddress.map { String(cString: $0) } ?? ""
        }
        return path.isEmpty ? nil : path
    }
}
