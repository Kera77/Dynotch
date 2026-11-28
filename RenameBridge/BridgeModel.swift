import AppKit
import Observation

/// Installs the Wingmate of this bridge's own release (spec RN-10). Writes nothing but the
/// *Launch at login* note (spec U-12) and the update log.
@MainActor
@Observable
final class BridgeModel {
    enum Phase: Equatable {
        case working
        case failed(String)
    }

    static let oldIdentifier = "com.peterkereki.Dynotch"

    private(set) var phase: Phase = .working

    func start() {
        phase = .working
        Task { await run() }
    }

    private func run() async {
        let version = AppInfo.version
        do {
            guard let url = UpdateLogic.release(forVersion: version),
                  let release = UpdateLogic.release(fromTagJSON: try await UpdateInstaller.fetch(url))
            else { throw UpdateInstaller.Failure(message: "Wingmate \(version) was not found.") }
            let running = Bundle.main.bundleURL
            guard UpdateLogic.canReplace(appAt: running.path) else {
                throw UpdateInstaller.Failure(message: "This copy does not run from an Applications folder.")
            }
            let prepared = try await UpdateInstaller.prepare(release)
            let destination = running.deletingLastPathComponent().appendingPathComponent(prepared.app.lastPathComponent)
            UpdateInstaller.prepareForRename()
            Self.forgetOldPermissions()
            DiagnosticsLog.append("updates", "bridge: installing Wingmate \(version)")
            try UpdateInstaller.launchInstaller(newApp: prepared.app, target: destination, running: running, folder: prepared.folder)
            DiagnosticsLog.flush()
            NSApp.terminate(nil)
        } catch {
            let message = (error as? UpdateInstaller.Failure)?.message ?? error.localizedDescription
            DiagnosticsLog.append("updates", "bridge: failed: \(message)")
            phase = .failed(message)
        }
    }

    /// The old name's rows in System Settings › Privacy would stay behind as "Dynotch" (spec RN-10).
    /// Only possible while the old bundle is still installed.
    private static func forgetOldPermissions() {
        guard Bundle.main.bundleIdentifier == oldIdentifier else { return }
        let result = ProcessRunner.run("/usr/bin/tccutil", ["reset", "All", oldIdentifier], timeout: 10)
        DiagnosticsLog.append("updates", "bridge: old permissions reset \(result?.succeeded == true ? "done" : "failed")")
    }
}
