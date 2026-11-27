import CoreServices
import Foundation

/// A file or folder the cleaner can move to the Trash (spec TT-2…TT-4).
struct CleanerItem: Sendable, Hashable, Identifiable {
    let url: URL
    let size: Int64
    /// Belongs to a running app: listed, never selected by default (spec TT-3).
    var inUse = false
    /// A large file's last change (spec TT-21).
    var modified: Date?

    var id: URL { url }
}

/// The leftovers of one app that is no longer on the Mac (spec TT-2).
struct CleanerGroup: Sendable, Hashable, Identifiable {
    let bundleID: String
    let items: [CleanerItem]

    var id: String { bundleID }
    var size: Int64 { items.reduce(0) { $0 + $1.size } }
}

/// An installed app the cleaner can remove with its files (spec TT-4).
struct CleanerApp: Sendable, Hashable, Identifiable {
    let url: URL
    let name: String
    let bundleID: String
    let size: Int64
    /// When it was last opened, from Spotlight (spec TT-20).
    var lastUsed: Date?

    var id: URL { url }
}

/// Finding leftovers, caches and an app's files (spec TT-2…TT-6). Runs off the main thread.
enum CleanerScan {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static var library: URL { home.appending(path: "Library") }

    /// The `~/Library` folders whose items are named by an app's identifier (spec TT-2).
    static let leftoverFolders = [
        "Application Support", "Caches", "Preferences", "Containers", "Saved Application State",
        "HTTPStorages", "WebKit", "Logs", "Cookies"
    ]

    static let appFolders = ["/Applications", "/System/Applications"]

    /// Never listed or removed (spec TT-2, TT-5).
    static func isProtected(_ bundleID: String) -> Bool {
        let id = bundleID.lowercased()
        let own = (Bundle.main.bundleIdentifier ?? "com.dynotch").lowercased()
        return id.hasPrefix("com.apple.") || id == own || id.hasPrefix(own + ".") || id.hasPrefix("com.dynotch")
    }

    /// The app identifier an item's name stands for, or nil: `com.vendor.app`, without
    /// `.plist`, `.savedState` or `.binarycookies` (spec TT-2).
    static func bundleID(fromItemName name: String) -> String? {
        var name = name
        for suffix in [".plist", ".savedState", ".binarycookies"] where name.hasSuffix(suffix) {
            name.removeLast(suffix.count)
        }
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard name.unicodeScalars.allSatisfy({ allowed.contains($0) || $0 == "." }),
              parts[0].allSatisfy(\.isLetter) else { return nil }
        return name
    }

    /// The first two parts of an identifier: `com.vendor`.
    static func vendor(of bundleID: String) -> String {
        bundleID.lowercased().split(separator: ".").prefix(2).joined(separator: ".")
    }

    /// Whether an item named after `bundleID` still belongs to something on the Mac: an
    /// installed or running app of the same vendor, or one Launch Services knows (spec TT-2).
    static func isInUse(_ bundleID: String, installed: Set<String>, running: Set<String>) -> Bool {
        let id = bundleID.lowercased()
        let vendor = vendor(of: id)
        if isProtected(id) || running.contains(where: { $0 == id || $0.hasPrefix(id + ".") || id.hasPrefix($0 + ".") }) {
            return true
        }
        if installed.contains(where: { $0 == id || vendor == Self.vendor(of: $0) }) { return true }
        return launchServicesKnows(bundleID)
    }

    static func launchServicesKnows(_ bundleID: String) -> Bool {
        guard let urls = LSCopyApplicationURLsForBundleIdentifier(bundleID as CFString, nil)?.takeRetainedValue() as? [URL]
        else { return false }
        return urls.contains { !$0.path.contains("/.Trash/") }
    }

    // MARK: - Installed apps

    static func appURLs() -> [URL] {
        let roots = appFolders.map { URL(filePath: $0) } + [home.appending(path: "Applications")]
        var apps: [URL] = []
        for root in roots {
            let items = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for item in items {
                if item.pathExtension == "app" {
                    apps.append(item)
                } else if (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    // One level down: /Applications/Utilities and vendor folders.
                    let inner = (try? FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)) ?? []
                    apps += inner.filter { $0.pathExtension == "app" }
                }
            }
        }
        return apps
    }

    static func installedBundleIDs() -> Set<String> {
        Set(appURLs().compactMap { Bundle(url: $0)?.bundleIdentifier?.lowercased() })
    }

    /// The apps the owner can remove: not the system's, not Wingmate (spec TT-4).
    static func removableApps() -> [CleanerApp] {
        appURLs()
            .filter { !$0.path.hasPrefix("/System/") }
            .compactMap { url -> CleanerApp? in
                guard let id = Bundle(url: url)?.bundleIdentifier, !isProtected(id) else { return nil }
                return CleanerApp(
                    url: url, name: url.deletingPathExtension().lastPathComponent, bundleID: id, size: size(of: url),
                    lastUsed: lastUsed(of: url)
                )
            }
            .sorted { $0.size > $1.size }
    }

    /// When the app was last opened, from Spotlight's `kMDItemLastUsedDate` (spec TT-20).
    static func lastUsed(of url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    // MARK: - Sizes

    /// The space a file or folder takes on disk (allocated size).
    static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isDirectoryKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        guard values.isDirectory == true else { return Int64(values.totalFileAllocatedSize ?? 0) }
        guard let walk = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), errorHandler: { _, _ in true })
        else { return 0 }
        var total: Int64 = 0
        for case let file as URL in walk {
            total += Int64((try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
        }
        return total
    }

    /// The items of a folder, or nil when macOS does not let Wingmate read it (spec TT-6).
    static func contents(of folder: URL) -> [URL]? {
        do {
            return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        } catch let error as CocoaError where error.code == .fileReadNoPermission {
            return nil
        } catch {
            return []
        }
    }
}
