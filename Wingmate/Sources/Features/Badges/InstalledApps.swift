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

    /// From the system's own CoreServices folder only these show up; the rest are helpers
    /// such as AddressBookUrlForwarder (spec B-9).
    static let coreServicesAllowed: Set<String> = ["com.apple.finder"]

    /// Every app in the Applications folders (and one folder level below), by name, without
    /// background helpers that never show a Dock icon (spec B-1, B-9).
    static func scan() -> [InstalledApp] {
        var found: [String: InstalledApp] = [:]
        for root in roots {
            let isCoreServices = root.hasSuffix("CoreServices")
            for path in bundles(in: root, descend: !isCoreServices) {
                guard let app = app(at: path), found[app.bundleID] == nil,
                      !isCoreServices || coreServicesAllowed.contains(app.bundleID),
                      !isBackgroundOnly(Bundle(path: path)?.infoDictionary) else { continue }
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

    /// An agent or background-only app (no Dock icon) can never have a Dock badge (spec B-9).
    static func isBackgroundOnly(_ info: [String: Any]?) -> Bool {
        guard let info else { return false }
        return flag(info["LSUIElement"]) || flag(info["LSBackgroundOnly"])
    }

    private static func flag(_ value: Any?) -> Bool {
        switch value {
        case let bool as Bool: bool
        case let number as NSNumber: number.boolValue
        case let text as String: text == "1" || text.lowercased() == "true" || text.lowercased() == "yes"
        default: false
        }
    }

    static func app(at path: String) -> InstalledApp? {
        guard let bundleID = Bundle(path: path)?.bundleIdentifier else { return nil }
        var name = FileManager.default.displayName(atPath: path)
        if name.hasSuffix(".app") { name.removeLast(4) }
        return InstalledApp(bundleID: bundleID, name: name, path: path)
    }
}
