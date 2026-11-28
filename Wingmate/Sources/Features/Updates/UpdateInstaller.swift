import Foundation
import ServiceManagement

/// Downloads, checks and puts a release in place; shared by the app (spec U-2, U-3) and the
/// rename bridge (spec RN-10), so it needs nothing but the updater's own code.
enum UpdateInstaller {
    struct Failure: Error {
        let message: String
    }

    /// A GitHub API answer.
    static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Wingmate", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return try await URLSession.shared.data(for: request).0
    }

    /// Downloads and unpacks the release and makes sure it is the real thing: the listed
    /// checksum, the expected version, and the same signature as this app (spec U-2).
    static func prepare(_ release: ReleaseInfo) async throws -> (app: URL, folder: URL) {
        let (archive, _) = try await URLSession.shared.data(from: release.archive)
        guard let checksums = release.checksums else { throw Failure(message: "The release has no checksums.") }
        let (sums, _) = try await URLSession.shared.data(from: checksums)
        let expected = UpdateLogic.expectedHash(forFile: release.archiveName, inChecksums: String(bytes: sums, encoding: .utf8) ?? "")
        guard let expected, expected == UpdateLogic.sha256(of: archive) else {
            throw Failure(message: "The download does not match its checksum.")
        }
        return try await Task.detached {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("wingmate-update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let zip = folder.appendingPathComponent(release.archiveName)
            try archive.write(to: zip)
            let unpack = ProcessRunner.run("/usr/bin/ditto", ["-x", "-k", zip.path, folder.path], timeout: 120)
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            let app = folder.appendingPathComponent(UpdateLogic.appBundle(in: names) ?? "Wingmate.app")
            let version = Bundle(url: app)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            guard unpack?.succeeded == true, version == release.version else {
                throw Failure(message: "The download is not Wingmate \(release.version).")
            }
            guard UpdateLogic.isSignedLikeRunningApp(appAt: app) else {
                throw Failure(message: "The download is not signed like this copy of Wingmate.")
            }
            return (app, folder)
        }.value
    }

    /// Before the app is replaced by its renamed self: remembers *Launch at login* for the new app
    /// and takes this one out of the login items, as its bundle goes away (spec U-12).
    static func prepareForRename() {
        let enabled = SMAppService.mainApp.status == .enabled
        UserDefaults.standard.set(enabled, forKey: "launchAtLoginBeforeRename")
        if enabled { try? SMAppService.mainApp.unregister() }
        DiagnosticsLog.append("updates", "renamed app, launch at login was \(enabled ? "on" : "off")")
    }

    static func launchInstaller(newApp: URL, target: URL, running: URL, folder: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Detached, so it outlives this app.
        process.arguments = [
            "-c", "( \(UpdateLogic.installScript)\n) >/dev/null 2>&1 &", "wingmate-update",
            String(ProcessInfo.processInfo.processIdentifier), newApp.path, target.path, folder.path, running.path
        ]
        try process.run()
    }
}
