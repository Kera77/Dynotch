import AppKit

/// Reading the Focus files (needs Full Disk Access, like the notifications; spec E-20d).
enum FocusFiles {
    struct Snapshot: Equatable, Sendable {
        var modes: [FocusMode]
        var activeID: String?
        /// The files' symbol names, and the one drawn when it differs ("x → moon.fill").
        var symbolNames: [String] = []
    }

    nonisolated static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb/DB")
    }

    nonisolated static func read() -> Snapshot {
        let root = (try? Data(contentsOf: folder.appendingPathComponent("ModeConfigurations.json")))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) }
        let modes = root.map(modes(in:)) ?? []
        let raw = root.map(rawSymbols(in:)) ?? [:]
        let active = (try? Data(contentsOf: folder.appendingPathComponent("Assertions.json")))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) }
            .flatMap(activeID(in:))
        let names = modes.map { mode in
            let file = raw[mode.id] ?? "none"
            return file == mode.symbol ? file : "\(file) → \(mode.symbol)"
        }
        return Snapshot(modes: modes, activeID: active, symbolNames: names)
    }

    nonisolated private static func rawSymbols(in root: Any) -> [String: String] {
        guard let configurations = MacFocus.find("modeConfigurations", in: root) as? [String: Any] else { return [:] }
        var found: [String: String] = [:]
        for (key, value) in configurations {
            let mode = (value as? [String: Any])?["mode"] as? [String: Any] ?? [:]
            found[mode["modeIdentifier"] as? String ?? key] = mode["symbolImageName"] as? String
        }
        return found
    }

    /// Every configured Focus, Do Not Disturb first, then by name.
    nonisolated static func modes(in root: Any) -> [FocusMode] {
        guard let configurations = MacFocus.find("modeConfigurations", in: root) as? [String: Any] else { return [] }
        let found = configurations.compactMap { key, value -> FocusMode? in
            guard let configuration = value as? [String: Any] else { return nil }
            let mode = configuration["mode"] as? [String: Any] ?? [:]
            let id = mode["modeIdentifier"] as? String ?? key
            let name = (mode["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? FocusMode.fallbackName(for: id)
            let symbol = FocusMode.usableSymbol(mode["symbolImageName"] as? String, id: id, modeName: name)
            return FocusMode(id: id, name: name, symbol: symbol, tint: mode["tintColorName"] as? String)
        }
        return found.sorted { lhs, rhs in
            let lhsDefault = lhs.id.hasSuffix(".default"), rhsDefault = rhs.id.hasSuffix(".default")
            if lhsDefault != rhsDefault { return lhsDefault }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// The active Focus's id; nil when none is on.
    nonisolated static func activeID(in root: Any) -> String? {
        guard let records = MacFocus.find("storeAssertionRecords", in: root) as? [[String: Any]], let first = records.first else {
            return nil
        }
        return MacFocus.find("assertionDetailsModeIdentifier", in: first) as? String ?? "com.apple.donotdisturb.mode.default"
    }
}
