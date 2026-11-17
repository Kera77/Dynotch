import AppKit
import Combine

/// A file kept in the tray: a reference to it, which follows the file when it moves (spec FT-2).
struct TrayItem: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    let bookmark: Data
    let name: String
    var added = Date()
}

/// A folder attached to the tray (spec FT-4).
struct TrayFolder: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    let bookmark: Data
    let name: String
    /// Index into the dot colours.
    let colour: Int
}

/// The file tray: dropped files and attached folders (spec FT-1…FT-7).
@MainActor
final class TrayStore: ObservableObject {
    @Published private(set) var items: [TrayItem] = []
    @Published private(set) var folders: [TrayFolder] = []
    /// nil: the tray itself; otherwise an attached folder, whose changes are followed (spec FT-9).
    @Published var selectedFolder: UUID? {
        didSet { watchSelectedFolder() }
    }
    private let watcher = FolderWatcher()
    /// Days after which a file leaves the tray; 0: never (spec FT-6).
    @Published var retentionDays: Int {
        didSet {
            defaults.set(retentionDays, forKey: Self.retentionKey)
            dropExpired()
        }
    }

    /// The files as a list instead of tiles (spec FT-11).
    @Published var showsList: Bool {
        didSet { defaults.set(showsList, forKey: "trayShowsList") }
    }

    static let retentionChoices = [0, 1, 3, 7, 14, 30]
    private static let retentionKey = "trayRetentionDays"
    private let defaults: UserDefaults
    private let folder: URL

    init(defaults: UserDefaults = .standard, folder: URL? = nil) {
        self.defaults = defaults
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.folder = folder ?? support.appendingPathComponent("Dynotch/Tray")
        retentionDays = defaults.object(forKey: Self.retentionKey) as? Int ?? 0
        showsList = defaults.bool(forKey: "trayShowsList")
        load()
        dropExpired()
    }

    // MARK: - The tray

    /// Keeps the files. Those without a lasting place (dragged from a browser or a screenshot
    /// tool, in a temporary folder) are copied into Dynotch's tray folder first.
    func add(_ urls: [URL]) {
        var added: [TrayItem] = []
        var seen: Set<String> = []
        for url in urls where seen.insert(url.standardizedFileURL.path).inserted {
            let kept = Self.isTemporary(url) ? copyIntoTray(url) ?? url : url
            guard let bookmark = try? kept.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil),
                  !items.contains(where: { resolve($0)?.standardizedFileURL == kept.standardizedFileURL })
            else { continue }
            added.append(TrayItem(bookmark: bookmark, name: kept.lastPathComponent))
        }
        guard !added.isEmpty else { return }
        items = added + items
        selectedFolder = nil
        persist()
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
        var stale = false
        let url = try? URL(resolvingBookmarkData: item.bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// The tray's files that still exist, newest first.
    var trayFiles: [(item: TrayItem, url: URL)] {
        items.compactMap { item in resolve(item).map { (item, $0) } }
    }

    private func dropExpired() {
        guard retentionDays > 0 else { return }
        let limit = Date().addingTimeInterval(-Double(retentionDays) * 86_400)
        let kept = items.filter { $0.added >= limit }
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
        selectedFolder = added.id
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

    /// The folder's files, newest first, without hidden ones.
    func contents(of folder: TrayFolder) -> [URL] {
        guard let url = url(of: folder) else { return [] }
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let found = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )) ?? []
        func date(_ url: URL) -> Date {
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        return Array(found.sorted { date($0) > date($1) }.prefix(300))
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
        objectWillChange.send()
    }

    private func watchSelectedFolder() {
        let folder = folders.first { $0.id == selectedFolder }
        watcher.watch(folder.flatMap(url(of:))) { [weak self] in self?.objectWillChange.send() }
    }

    /// Swiping steps between the tray and the folders (spec FT-4); false at either end.
    func step(by offset: Int) -> Bool {
        let tabs: [UUID?] = [nil] + folders.map(\.id)
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
