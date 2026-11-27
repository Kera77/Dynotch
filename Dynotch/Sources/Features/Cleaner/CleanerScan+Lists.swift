import Foundation

/// What one scan found (spec TT-2, TT-3, TT-6).
struct CleanerResult: Sendable {
    var leftovers: [CleanerGroup] = []
    var caches: [CleanerItem] = []
    var apps: [CleanerApp] = []
    /// Files over 500 MB in the owner's folders, looked for only on the Large files tab (spec TT-21).
    var largeFiles: [CleanerItem] = []
    /// A folder could not be read: Full Disk Access would show more (spec TT-6).
    var needsFullDiskAccess = false
}

extension CleanerScan {
    /// Caches below this are not worth listing (spec TT-3).
    static let minimumCache: Int64 = 1_000_000
    /// Selected by default above this, when not in use (spec TT-3).
    static let selectedCache: Int64 = 50_000_000

    static func scan(running: Set<String>) -> CleanerResult {
        var result = CleanerResult()
        let installed = installedBundleIDs()
        result.leftovers = leftovers(installed: installed, running: running, result: &result)
        result.caches = caches(running: running, result: &result)
        result.apps = removableApps()
        return result
    }

    // MARK: - Leftovers (spec TT-2)

    private static func leftovers(installed: Set<String>, running: Set<String>, result: inout CleanerResult) -> [CleanerGroup] {
        var found: [String: [CleanerItem]] = [:]
        for folder in leftoverFolders {
            guard let items = contents(of: library.appending(path: folder)) else {
                result.needsFullDiskAccess = true
                continue
            }
            for item in items {
                guard let id = bundleID(fromItemName: item.lastPathComponent),
                      !isInUse(id, installed: installed, running: running) else { continue }
                found[id.lowercased(), default: []].append(CleanerItem(url: item, size: size(of: item)))
            }
        }
        return found.map { CleanerGroup(bundleID: $0.key, items: $0.value.sorted { $0.size > $1.size }) }
            .sorted { $0.size > $1.size }
    }

    // MARK: - Caches (spec TT-3)

    /// Developer caches, when they exist.
    static var toolCaches: [URL] {
        [
            library.appending(path: "Developer/Xcode/DerivedData"),
            library.appending(path: "Caches/Homebrew"),
            home.appending(path: ".npm/_cacache"),
            library.appending(path: "Caches/pip")
        ]
    }

    private static func caches(running: Set<String>, result: inout CleanerResult) -> [CleanerItem] {
        var urls: [URL] = []
        if let items = contents(of: library.appending(path: "Caches")) {
            urls += items.filter { !toolCaches.contains($0) }
        } else {
            result.needsFullDiskAccess = true
        }
        urls += toolCaches.filter { FileManager.default.fileExists(atPath: $0.path) }
        // Each app's logs on their own; Wingmate's stay (spec TT-3).
        urls += (contents(of: library.appending(path: "Logs")) ?? []).filter { $0.lastPathComponent != "Dynotch" }
        return urls.compactMap { url -> CleanerItem? in
            let id = bundleID(fromItemName: url.lastPathComponent)
            if let id, isProtected(id) { return nil }
            let size = size(of: url)
            guard size >= minimumCache else { return nil }
            let inUse = id.map { id in running.contains { $0 == id.lowercased() || $0.hasPrefix(id.lowercased() + ".") } } ?? false
            return CleanerItem(url: url, size: size, inUse: inUse)
        }
        .sorted { $0.size > $1.size }
    }

    // MARK: - An app's files (spec TT-4)

    static func files(of app: CleanerApp) -> [CleanerItem] {
        let id = app.bundleID.lowercased()
        var urls: [URL] = []
        for folder in leftoverFolders {
            for item in contents(of: library.appending(path: folder)) ?? [] {
                let name = item.lastPathComponent
                let itemID = bundleID(fromItemName: name)?.lowercased()
                let sameName = ["Application Support", "Caches"].contains(folder) && name == app.name
                if itemID == id || itemID?.hasPrefix(id + ".") == true || sameName { urls.append(item) }
            }
        }
        for item in contents(of: library.appending(path: "Group Containers")) ?? []
        where item.lastPathComponent.lowercased().contains(id) {
            urls.append(item)
        }
        for item in contents(of: library.appending(path: "LaunchAgents")) ?? []
        where item.lastPathComponent.lowercased().hasPrefix(id) {
            urls.append(item)
        }
        return urls.map { CleanerItem(url: $0, size: size(of: $0)) }.sorted { $0.size > $1.size }
    }

    // MARK: - Large files (spec TT-21)

    static let largeFileMinimum: Int64 = 500_000_000
    static var largeFolders: [URL] {
        ["Downloads", "Desktop", "Documents", "Movies", "Library/Containers"].map { home.appending(path: $0) }
    }

    /// Files over 500 MB, largest first, at most 200; inside app bundles and hidden files are skipped.
    static func largeFiles() -> [CleanerItem] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .contentModificationDateKey]
        var found: [CleanerItem] = []
        for folder in largeFolders {
            guard let walk = FileManager.default.enumerator(
                at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }
            for case let file as URL in walk {
                guard let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
                let size = Int64(values.totalFileAllocatedSize ?? 0)
                guard size >= largeFileMinimum else { continue }
                found.append(CleanerItem(url: file, size: size, modified: values.contentModificationDate))
            }
        }
        return Array(found.sorted { $0.size > $1.size }.prefix(200))
    }

    /// Whether `url` lies where the cleaner may remove things: the home Library or an app
    /// folder, never the system (spec TT-5); a large file also in the owner's folders (spec TT-21).
    static func mayRemove(_ url: URL, largeFile: Bool = false) -> Bool {
        let path = url.standardizedFileURL.path
        guard !path.hasPrefix("/System/"), !path.contains("/com.apple.") else { return false }
        let libraryPath = library.path + "/"
        let allowed = [libraryPath, home.appending(path: "Applications").path + "/", "/Applications/"] + toolCaches.map(\.path)
            + (largeFile ? largeFolders.map { $0.path + "/" } : [])
        return allowed.contains { path.hasPrefix($0) } && path != library.path
    }
}
