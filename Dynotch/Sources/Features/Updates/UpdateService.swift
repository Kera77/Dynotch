import AppKit
import Combine

/// Keeps Dynotch up to date from its GitHub releases (spec U-1…U-4).
@MainActor
final class UpdateService: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)
        case installing(String)
        case failed(String)
    }

    struct Failure: Error {
        let message: String
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastChecked: Date?
    /// New versions are installed without asking (spec U-3).
    @Published var installsAutomatically: Bool {
        didSet { defaults.set(!installsAutomatically, forKey: Self.manualKey) }
    }

    private static let manualKey = "updatesManual"
    private static let versionKey = "lastRunVersion"
    private static let interval: TimeInterval = 6 * 3600

    private let defaults: UserDefaults
    private var timer: Timer?
    private var found: ReleaseInfo?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        installsAutomatically = !defaults.bool(forKey: Self.manualKey)
    }

    /// The version this copy replaced, once after an update (for the "updated" notice).
    func versionUpdatedFrom(current: String = AppInfo.version) -> String? {
        let previous = defaults.string(forKey: Self.versionKey)
        defaults.set(current, forKey: Self.versionKey)
        guard let previous, previous != current, UpdateLogic.isNewer(current, than: previous) else { return nil }
        return previous
    }

    func start() {
        guard timer == nil else { return }
        self.timer = RepeatingTimer.start(every: Self.interval) { [weak self] in self?.check() }
        // Not during launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    /// Looks for a newer release; installs it if that is automatic or the user asked for it.
    func check(installIfFound: Bool? = nil) {
        guard state != .checking, !isInstalling, let url = UpdateLogic.latestRelease else { return }
        state = .checking
        let install = installIfFound ?? installsAutomatically
        Task { [weak self] in
            do {
                var request = URLRequest(url: url)
                request.setValue("Dynotch", forHTTPHeaderField: "User-Agent")
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let self else { return }
                self.lastChecked = Date()
                guard let release = UpdateLogic.release(fromJSON: data) else { throw Failure(message: "No release found.") }
                guard UpdateLogic.isNewer(release.version, than: AppInfo.version) else {
                    self.state = .upToDate
                    return
                }
                self.found = release
                self.state = .available(release.version)
                if install { self.install() }
            } catch {
                self?.state = .failed((error as? Failure)?.message ?? error.localizedDescription)
            }
        }
    }

    private var isInstalling: Bool {
        if case .installing = state { return true }
        return false
    }

    /// Downloads the found release, checks it, replaces this app and starts the new one.
    func install() {
        guard let release = found, !isInstalling else { return }
        let target = Bundle.main.bundleURL
        guard UpdateLogic.canReplace(appAt: target.path) else {
            state = .failed("This copy cannot update itself (it does not run from an Applications folder).")
            return
        }
        state = .installing(release.version)
        Task { [weak self] in
            do {
                let prepared = try await Self.prepare(release)
                DiagnosticsLog.append("updates", "installing \(release.version)")
                try Self.launchInstaller(newApp: prepared.app, target: target, folder: prepared.folder)
                NSApp.terminate(nil)
            } catch {
                let message = (error as? Failure)?.message ?? error.localizedDescription
                DiagnosticsLog.append("updates", "update to \(release.version) failed: \(message)")
                self?.state = .failed(message)
            }
        }
    }

    /// Downloads and unpacks the release and makes sure it is the real thing: the listed
    /// checksum, the expected version, and the same signature as this app (spec U-2).
    private static func prepare(_ release: ReleaseInfo) async throws -> (app: URL, folder: URL) {
        let (archive, _) = try await URLSession.shared.data(from: release.archive)
        guard let checksums = release.checksums else { throw Failure(message: "The release has no checksums.") }
        let (sums, _) = try await URLSession.shared.data(from: checksums)
        let expected = UpdateLogic.expectedHash(forFile: release.archiveName, inChecksums: String(bytes: sums, encoding: .utf8) ?? "")
        guard let expected, expected == UpdateLogic.sha256(of: archive) else {
            throw Failure(message: "The download does not match its checksum.")
        }
        return try await Task.detached {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("dynotch-update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let zip = folder.appendingPathComponent(release.archiveName)
            try archive.write(to: zip)
            let unpack = ProcessRunner.run("/usr/bin/ditto", ["-x", "-k", zip.path, folder.path], timeout: 120)
            let app = folder.appendingPathComponent("Dynotch.app")
            let version = Bundle(url: app)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            guard unpack?.succeeded == true, version == release.version else {
                throw Failure(message: "The download is not Dynotch \(release.version).")
            }
            guard UpdateLogic.isSignedLikeRunningApp(appAt: app) else {
                throw Failure(message: "The download is not signed like this copy of Dynotch.")
            }
            return (app, folder)
        }.value
    }

    private static func launchInstaller(newApp: URL, target: URL, folder: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Detached, so it outlives this app.
        process.arguments = [
            "-c", "( \(UpdateLogic.installScript)\n) >/dev/null 2>&1 &", "dynotch-update",
            String(ProcessInfo.processInfo.processIdentifier), newApp.path, target.path, folder.path
        ]
        try process.run()
    }
}
