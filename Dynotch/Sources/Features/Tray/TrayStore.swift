import AppKit
import Observation

/// A file kept in the tray: a reference to it, which follows the file when it moves (spec FT-2).
struct TrayItem: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    let bookmark: Data
    let name: String
    var added = Date()
    /// Put in by itself from ~/Downloads, so it leaves on the downloads' own schedule (spec FT-15).
    var download: Bool?
}

/// A folder attached to the tray (spec FT-4).
struct TrayFolder: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    let bookmark: Data
    let name: String
    /// Index into the dot colours; changeable from the tab's menu (spec FT-4b).
    var colour: Int
}

/// The file tray: dropped files and attached folders (spec FT-1…FT-7).
@MainActor
@Observable
final class TrayStore {
    private(set) var items: [TrayItem] = [] {
        didSet { refreshShownFiles() }
    }
    /// The picked tab's files, read off the main thread and only when something changed (spec FT-16).
    private(set) var shownFiles: [URL] = []
    /// The tray item behind each shown file of the tray tab.
    private(set) var trayItemByURL: [URL: TrayItem] = [:]
    /// Each item's place, resolved from its bookmark once (spec FT-16).
    @ObservationIgnored private var resolvedURLs: [UUID: URL] = [:]
    @ObservationIgnored private var listing: Task<Void, Never>?
    private(set) var folders: [TrayFolder] = []
    /// nil: the tray itself; otherwise an attached folder, whose changes are followed (spec FT-9).
    var selectedFolder: UUID? {
        didSet {
            watchSelectedFolder()
            refreshShownFiles()
            // The tab stays picked across restarts (spec MG-10).
            defaults.set(selectedFolder?.uuidString, forKey: "traySelectedFolder")
        }
    }
    private let watcher = FolderWatcher()
    /// The built-in Screenshots tab: the newest shots of ~/Pictures/Screenshots (spec SH-11).
    static let screenshotsID = UUID(uuidString: "5C2E5C2E-0000-4000-8000-000000000001") ?? UUID()
    /// Whether the screenshot tool is on, so its tab shows.
    var showsScreenshots = true {
        didSet { if showsScreenshots != oldValue { refreshShownFiles() } }
    }
    /// The pointer is over the tabs: a swipe there steps between them (spec FT-4d).
    @ObservationIgnored var isOverTabs = false
    /// Days after which a file leaves the tray; 0: never (spec FT-6).
    var retentionDays: Int {
        didSet {
            defaults.set(retentionDays, forKey: Self.retentionKey)
            dropExpired()
        }
    }

    /// Finished downloads go into the tray by themselves (spec FT-15).
    var keepsDownloads: Bool {
        didSet { defaults.set(keepsDownloads, forKey: "trayKeepsDownloads") }
    }
    /// Days after which a download leaves the tray; 0: never (spec FT-15).
    var downloadRetentionDays: Int {
        didSet {
            defaults.set(downloadRetentionDays, forKey: "trayDownloadRetentionDays")
            dropExpired()
        }
    }
    @ObservationIgnored private var expiryCheck: Task<Void, Never>?

    /// List or tiles, kept per tab (spec FT-11, FT-11b); tabs from before keep the old shared choice.
    private var listByTab: [String: Bool] {
        didSet { defaults.set(listByTab, forKey: "trayListByTab") }
    }
    private let sharedList: Bool

    /// The dot colours of the Tray and Screenshots tabs, by "tray" / "screenshots" (spec FT-4c).
    private var fixedColours: [String: Int] {
        didSet { defaults.set(fixedColours, forKey: "trayTabColours") }
    }

    /// Blue for the tray, orange for screenshots until changed.
    func colour(ofFixed tab: String) -> Int {
        fixedColours[tab] ?? (tab == "tray" ? 2 : 3)
    }

    func setColour(_ colour: Int, ofFixed tab: String) {
        fixedColours[tab] = colour
    }

    /// The open tab's files as a list instead of tiles.
    var showsList: Bool {
        get { listByTab[selectedFolder?.uuidString ?? "tray"] ?? sharedList }
        set { listByTab[selectedFolder?.uuidString ?? "tray"] = newValue }
    }

    static let retentionChoices = [0, 1, 3, 7, 14, 30]
    private static let retentionKey = "trayRetentionDays"
    private let defaults: UserDefaults
    /// Dynotch's own tray folder, where files without a lasting place are copied (spec FT-2).
    let folder: URL

    init(defaults: UserDefaults = .standard, folder: URL? = nil) {
        self.defaults = defaults
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.folder = folder ?? support.appendingPathComponent("Dynotch/Tray")
        retentionDays = defaults.object(forKey: Self.retentionKey) as? Int ?? 0
        keepsDownloads = defaults.object(forKey: "trayKeepsDownloads") as? Bool ?? true
        downloadRetentionDays = defaults.object(forKey: "trayDownloadRetentionDays") as? Int ?? 3
        sharedList = defaults.bool(forKey: "trayShowsList")
        listByTab = defaults.dictionary(forKey: "trayListByTab") as? [String: Bool] ?? [:]
        fixedColours = defaults.dictionary(forKey: "trayTabColours") as? [String: Int] ?? [:]
        load()
        dropExpired()
        let saved = defaults.string(forKey: "traySelectedFolder").flatMap(UUID.init(uuidString:))
        if let saved, saved == Self.screenshotsID || folders.contains(where: { $0.id == saved }) {
            selectedFolder = saved
            watchSelectedFolder()
        }
        refreshShownFiles()
        // Files also leave while the app keeps running for days (spec FT-15).
        expiryCheck = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
                self?.dropExpired()
            }
        }
    }

    // MARK: - The tray

    /// Keeps the files. Those without a lasting place (dragged from a browser or a screenshot
    /// tool, in a temporary folder) are copied into Dynotch's tray folder first.
    func add(_ urls: [URL], download: Bool = false) {
        var added: [TrayItem] = []
        var seen: Set<String> = []
        for url in urls where seen.insert(url.standardizedFileURL.path).inserted {
            let kept = Self.isTemporary(url) ? copyIntoTray(url) ?? url : url
            guard let bookmark = try? kept.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil),
                  !items.contains(where: { resolve($0)?.standardizedFileURL == kept.standardizedFileURL })
            else { continue }
            added.append(TrayItem(bookmark: bookmark, name: kept.lastPathComponent, download: download ? true : nil))
        }
        guard !added.isEmpty else { return }
        items = added + items
        selectedFolder = nil
        persist()
    }

    /// A finished download, on top of the tray, if wanted (spec FT-15).
    func addDownload(_ url: URL) {
        guard keepsDownloads else { return }
        add([url], download: true)
    }

    func remove(_ item: TrayItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clear() {
        items = []
        persist()
    }

    /// The file now; nil if it is gone.
    func resolve(_ item: TrayItem) -> URL? {
        // The bookmark follows a moved file: only a gone file resolves again (spec FT-16).
        if let known = resolvedURLs[item.id], FileManager.default.fileExists(atPath: known.path) { return known }
        var stale = false
        let url = try? URL(resolvingBookmarkData: item.bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        resolvedURLs[item.id] = url
        return url
    }

    /// The tray's files that still exist, newest first.
    var trayFiles: [(item: TrayItem, url: URL)] {
        items.compactMap { item in resolve(item).map { (item, $0) } }
    }

    func dropExpired(now: Date = Date()) {
        let kept = items.filter { item in
            let days = item.download == true ? downloadRetentionDays : retentionDays
            return days <= 0 || item.added >= now.addingTimeInterval(-Double(days) * 86_400)
        }
        if kept.count != items.count {
            items = kept
            persist()
        }
    }

    static func isTemporary(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let temporary = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path
        return path.hasPrefix(temporary) || path.hasPrefix("/private/var/folders/") || path.hasPrefix("/tmp/")
            || path.contains("/Library/Caches/")
    }

    /// Each copy in a folder of its own, so it keeps its name (spec FT-12).
    private func copyIntoTray(_ url: URL) -> URL? {
        let files = folder.appendingPathComponent("Files").appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        let target = files.appendingPathComponent(url.lastPathComponent)
        return (try? FileManager.default.copyItem(at: url, to: target)) == nil ? nil : target
    }

    /// "name.ext", or "name 2.ext" if taken.
    static func freeName(for name: String, in folder: URL) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var number = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)")
            number += 1
        }
        return candidate
    }

    // MARK: - Folders (spec FT-4, FT-5)

    func attachFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Attach"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url,
              let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return }
        let added = TrayFolder(bookmark: bookmark, name: url.lastPathComponent, colour: folders.count % 6)
        folders.append(added)
        listByTab[added.id.uuidString] = false
        selectedFolder = added.id
        persist()
    }

    func setColour(_ colour: Int, of folder: TrayFolder) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].colour = colour
        persist()
    }

    func detach(_ folder: TrayFolder) {
        folders.removeAll { $0.id == folder.id }
        if selectedFolder == folder.id { selectedFolder = nil }
        persist()
    }

    func url(of folder: TrayFolder) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: folder.bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    /// Files dropped on an attached folder: copied, or moved with Option (spec FT-5).
    func put(_ urls: [URL], into folder: TrayFolder, move: Bool) {
        guard let target = url(of: folder) else { return }
        for url in urls where url.deletingLastPathComponent().standardizedFileURL != target.standardizedFileURL {
            let destination = Self.freeName(for: url.lastPathComponent, in: target)
            if move {
                try? FileManager.default.moveItem(at: url, to: destination)
            } else {
                try? FileManager.default.copyItem(at: url, to: destination)
            }
        }
        refreshShownFiles()
    }

    private func watchSelectedFolder() {
        let folder = folders.first { $0.id == selectedFolder }
        let watched = selectedFolder == Self.screenshotsID ? ScreenshotFiles.folder : folder.flatMap(url(of:))
        watcher.watch(watched) { [weak self] in self?.refreshShownFiles() }
    }

    /// Swiping steps between the tray and the folders (spec FT-4); false at either end.
    func step(by offset: Int) -> Bool {
        let tabs: [UUID?] = [nil] + (showsScreenshots ? [Self.screenshotsID] : []) + folders.map(\.id)
        guard let index = tabs.firstIndex(of: selectedFolder) else { return false }
        let next = index + offset
        guard tabs.indices.contains(next) else { return false }
        selectedFolder = tabs[next]
        return true
    }

    // MARK: - Disk

    private struct Saved: Codable {
        var items: [TrayItem]
        var folders: [TrayFolder]
    }

    private var file: URL { folder.appendingPathComponent("tray.json") }

    private func load() {
        guard let data = try? Data(contentsOf: file), let stored = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        items = stored.items
        folders = stored.folders
    }

    private func persist() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(Saved(items: items, folders: folders)) else { return }
        try? data.write(to: file, options: .atomic)
    }
}

// MARK: - The shown files (spec FT-16)

extension TrayStore {
    /// The folder's files, newest first, without hidden ones.
    func contents(of folder: TrayFolder) -> [URL] {
        url(of: folder).map(Self.newestFiles(in:)) ?? []
    }

    /// A folder's files, newest first, at most 300; each date is read once.
    nonisolated static func newestFiles(in url: URL) -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let found = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )) ?? []
        let dated = found.map { file in
            (file, (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
        }
        return Array(dated.sorted { $0.1 > $1.1 }.prefix(300).map(\.0))
    }

    /// Reads the picked tab's files again: the tray's at once, a folder's in the background (spec FT-16).
    func refreshShownFiles() {
        listing?.cancel()
        let tab = selectedFolder
        if tab == nil {
            let files = trayFiles
            trayItemByURL = Dictionary(files.map { ($0.url, $0.item) }, uniquingKeysWith: { first, _ in first })
            shownFiles = files.map(\.url)
            return
        }
        trayItemByURL = [:]
        let isShots = tab == Self.screenshotsID
        let folder = isShots ? nil : folders.first { $0.id == tab }.flatMap(url(of:))
        listing = Task { [weak self] in
            let found = await Task.detached(priority: .userInitiated) {
                // The ten newest shots and recordings (spec SH-11).
                folder.map(TrayStore.newestFiles(in:)) ?? (isShots ? ScreenshotFiles.recent(10) : [])
            }.value
            guard !Task.isCancelled, let self, self.selectedFolder == tab else { return }
            if self.shownFiles != found { self.shownFiles = found }
        }
    }
}
