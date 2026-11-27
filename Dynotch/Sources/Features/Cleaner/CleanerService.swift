import AppKit
import Observation

/// The Cleaner module's state: what a scan found, what is selected, and moving it to the
/// Trash (spec TT-1…TT-6).
@MainActor
@Observable
final class CleanerService {
    static let shared = CleanerService()

    enum NotchGlance: Equatable { case cleaning, done }

    enum Tab: String, CaseIterable, Hashable {
        case leftovers, caches, apps

        var title: String {
            switch self {
            case .leftovers: "Leftovers"
            case .caches: "Caches"
            case .apps: "Apps"
            }
        }
    }

    var tab: Tab = .leftovers
    private(set) var result = CleanerResult()
    private(set) var hasScanned = false
    private(set) var isScanning = false
    /// The URLs ticked for the Trash (spec TT-2, TT-3).
    var selected: Set<URL> = []
    /// The app picked in the Apps tab and its files (spec TT-4).
    private(set) var app: CleanerApp?
    private(set) var appFiles: [CleanerItem] = []
    var appSearch = ""
    /// After a clean: "Freed 2.3 GB", and what could not be moved (spec TT-5).
    private(set) var freed: Int64?
    private(set) var failed = 0
    /// Moving to the Trash and the scan after it: the Cleaner can't be touched (spec TT-12).
    private(set) var isCleaning = false
    /// Beside the closed notch: the spinner while cleaning, then the green tick (spec TT-13).
    private(set) var notchGlance: NotchGlance?
    /// The Cleaner is open in a notch: a clean ending there needs no tick (spec TT-13).
    var isViewed = false {
        didSet { if isViewed, notchGlance == .done { notchGlance = nil } }
    }
    private var glanceTimer: Task<Void, Never>?
    private(set) var freeSpace: Int64 = 0
    private(set) var totalSpace: Int64 = 0

    /// What the Leftovers and Caches tabs would free with the current selection.
    var selectedItems: [CleanerItem] {
        switch tab {
        case .leftovers: result.leftovers.flatMap(\.items).filter { selected.contains($0.url) }
        case .caches: result.caches.filter { selected.contains($0.url) }
        case .apps: appFiles.filter { selected.contains($0.url) }
        }
    }

    /// Everything a scan found to clean, for the Home tile and the wings (spec TT-7).
    var cleanable: Int64 {
        result.leftovers.reduce(0) { $0 + $1.size } + result.caches.filter { !$0.inUse && $0.size >= CleanerScan.selectedCache }
            .reduce(0) { $0 + $1.size }
    }

    var shownApps: [CleanerApp] {
        let query = appSearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return result.apps }
        return result.apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func scanIfNeeded() {
        if !hasScanned { scan() }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        freed = nil
        refreshSpace()
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier?.lowercased() })
        Task {
            let result = await Task.detached(priority: .utility) { CleanerScan.scan(running: running) }.value
            self.result = result
            self.selected = Set(result.leftovers.flatMap(\.items).map(\.url))
                .union(result.caches.filter { !$0.inUse && $0.size >= CleanerScan.selectedCache }.map(\.url))
            self.hasScanned = true
            self.isScanning = false
            if self.isCleaning { self.finishCleaning() }
            CleanerLog.write("scan: \(result.leftovers.count) leftover apps, \(result.caches.count) caches, "
                + "\(result.apps.count) apps, fda=\(result.needsFullDiskAccess)")
        }
    }

    func toggle(_ urls: [URL]) {
        let allOn = urls.allSatisfy(selected.contains)
        if allOn { selected.subtract(urls) } else { selected.formUnion(urls) }
    }

    // MARK: - Apps (spec TT-4)

    func pick(_ app: CleanerApp?) {
        self.app = app
        appFiles = []
        freed = nil
        guard let app else { return }
        Task {
            let files = await Task.detached(priority: .userInitiated) { CleanerScan.files(of: app) }.value
            guard self.app == app else { return }
            appFiles = files
            selected.formUnion(files.map(\.url))
        }
    }

    func isRunning(_ app: CleanerApp) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty
    }

    func quit(_ app: CleanerApp) {
        NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).forEach { $0.terminate() }
    }

    // MARK: - Moving to the Trash (spec TT-5)

    /// The items the next clean moves: the selection, or the app with its ticked files.
    var pending: [CleanerItem] {
        guard tab == .apps, let app else { return selectedItems }
        return [CleanerItem(url: app.url, size: app.size)] + selectedItems
    }

    /// Off the main thread, the Cleaner covered until the list is scanned again (spec TT-12).
    func trashPending() {
        guard !isCleaning else { return }
        let all = pending
        let items = all.filter { CleanerScan.mayRemove($0.url) }
        let tab = tab
        isCleaning = true
        glanceTimer?.cancel()
        notchGlance = .cleaning
        Task {
            let (moved, freedNow) = await Task.detached(priority: .userInitiated) { Self.trash(items) }.value
            let failedNow = all.count - moved
            CleanerLog.write("trash: \(moved) moved, \(failedNow) failed, \(freedNow / 1_000_000) MB, tab=\(tab.rawValue)")
            selected.subtract(items.map(\.url))
            freed = freedNow
            failed = failedNow
            if tab == .apps { app = nil; appFiles = [] }
            scanAfterClean()
        }
    }

    nonisolated private static func trash(_ items: [CleanerItem]) -> (moved: Int, freed: Int64) {
        var freed: Int64 = 0
        var moved = 0
        for item in items where (try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)) != nil {
            freed += item.size
            moved += 1
        }
        return (moved, freed)
    }

    /// The tick waits beside the closed notch for ten minutes, unless the clean was watched (spec TT-13).
    private func finishCleaning() {
        isCleaning = false
        guard !isViewed else { return notchGlance = nil }
        notchGlance = .done
        glanceTimer = Task {
            try? await Task.sleep(for: .seconds(600))
            guard !Task.isCancelled, notchGlance == .done else { return }
            notchGlance = nil
        }
    }

    /// Hovering the tick opens the Cleaner: the tick has done its job (spec TT-13).
    func clearNotchGlance() {
        if notchGlance == .done { notchGlance = nil }
    }

    private func scanAfterClean() {
        let freedNow = freed
        let failedNow = failed
        scan()
        freed = freedNow
        failed = failedNow
    }

    func refreshSpace() {
        let values = try? CleanerScan.home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        freeSpace = values?.volumeAvailableCapacityForImportantUsage ?? 0
        totalSpace = Int64(values?.volumeTotalCapacity ?? 0)
    }

    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// `cleaner.log`: counts and sizes, never file names (spec TT-6).
enum CleanerLog {
    static func write(_ line: String) {
        DiagnosticsLog.append("cleaner", line)
    }
}
