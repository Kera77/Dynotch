import AppKit
import Observation

/// Keeps Wingmate up to date from its GitHub releases (spec U-1…U-4).
@MainActor
@Observable
final class UpdateService {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)
        case installing(String)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var lastChecked: Date?
    /// New versions are installed without asking (spec U-3).
    var installsAutomatically: Bool {
        didSet { defaults.set(!installsAutomatically, forKey: Self.manualKey) }
    }

    /// Test builds (prereleases) too, not only full releases (spec U-7).
    var betaChannel: Bool {
        didSet { defaults.set(betaChannel, forKey: Self.betaKey) }
    }

    private static let manualKey = "updatesManual"
    private static let betaKey = "updatesBeta"
    private static let versionKey = "lastRunVersion"
    private static let interval: TimeInterval = 6 * 3600

    private let defaults: UserDefaults
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var found: ReleaseInfo?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        installsAutomatically = !defaults.bool(forKey: Self.manualKey)
        betaChannel = defaults.bool(forKey: Self.betaKey)
        // Left over from the removed "Go back to" button (spec RF-21).
        defaults.removeObject(forKey: "previousVersion")
    }

    /// The version this copy replaced, once after an update (for the "updated" notice).
    func versionUpdatedFrom(current: String = AppInfo.version) -> String? {
        let previous = defaults.string(forKey: Self.versionKey)
        defaults.set(current, forKey: Self.versionKey)
        guard let previous, previous != current else { return nil }
        // Installed an older version by hand (scripts/install.sh): not an update.
        return UpdateLogic.isNewer(current, than: previous) ? previous : nil
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
        let beta = betaChannel
        guard state != .checking, !isInstalling,
              let url = beta ? UpdateLogic.recentReleases : UpdateLogic.latestRelease else { return }
        state = .checking
        let install = installIfFound ?? installsAutomatically
        Task { [weak self] in
            do {
                let data = try await UpdateInstaller.fetch(url)
                guard let self else { return }
                self.lastChecked = Date()
                let candidate = beta ? UpdateLogic.newestRelease(fromListJSON: data) : UpdateLogic.release(fromJSON: data)
                guard let release = candidate else { throw UpdateInstaller.Failure(message: "No release found.") }
                guard UpdateLogic.isNewer(release.version, than: AppInfo.version) else {
                    self.state = .upToDate
                    return
                }
                self.found = release
                self.state = .available(release.version)
                if install { self.install() }
            } catch {
                self?.state = .failed((error as? UpdateInstaller.Failure)?.message ?? error.localizedDescription)
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
                let prepared = try await UpdateInstaller.prepare(release)
                DiagnosticsLog.append("updates", "installing \(release.version)")
                let destination = target.deletingLastPathComponent().appendingPathComponent(prepared.app.lastPathComponent)
                if destination != target { UpdateInstaller.prepareForRename() }
                try UpdateInstaller.launchInstaller(newApp: prepared.app, target: destination, running: target, folder: prepared.folder)
                NSApp.terminate(nil)
            } catch {
                let message = (error as? UpdateInstaller.Failure)?.message ?? error.localizedDescription
                DiagnosticsLog.append("updates", "update to \(release.version) failed: \(message)")
                self?.state = .failed(message)
            }
        }
    }
}
