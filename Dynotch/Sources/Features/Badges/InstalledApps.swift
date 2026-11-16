import Foundation

/// An app found on this Mac (spec B-1).
struct InstalledApp: Identifiable, Equatable, Sendable {
    let bundleID: String
    let name: String
    let path: String

    var id: String { bundleID }
}

enum InstalledApps {
    private static var roots: [String] {
        ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications", "/System/Library/CoreServices"]
    }

    /// Every app in the Applications folders (and one folder level below), by name.
    static func scan() -> [InstalledApp] {
        var found: [String: InstalledApp] = [:]
        for root in roots {
            for path in bundles(in: root, descend: !root.hasSuffix("CoreServices")) {
                guard let app = app(at: path), found[app.bundleID] == nil else { continue }
                found[app.bundleID] = app
            }
        }
        return found.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func bundles(in folder: String, descend: Bool) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        return names.flatMap { name -> [String] in
            let path = folder + "/" + name
            if name.hasSuffix(".app") { return [path] }
            guard descend, !name.hasPrefix("."), !name.contains(".") else { return [] }
            return bundles(in: path, descend: false)
        }
    }

    static func app(at path: String) -> InstalledApp? {
        guard let bundleID = Bundle(path: path)?.bundleIdentifier else { return nil }
        var name = FileManager.default.displayName(atPath: path)
        if name.hasSuffix(".app") { name.removeLast(4) }
        return InstalledApp(bundleID: bundleID, name: name, path: path)
    }
}
