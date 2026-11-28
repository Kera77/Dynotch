import Foundation

/// Which displays each Spencer layout was made for, read from Spencer's own database without
/// changing it (spec SL-8): offers only the layouts made for the displays here (SL-13) and picks the
/// one made for exactly these displays (SL-9).
struct SpencerLayoutDisplays: Equatable, Sendable {
    /// Layout name → the display UUIDs (upper case) it was made for.
    var displays: [String: Set<String>] = [:]

    nonisolated static let databasePath = NSHomeDirectory() + "/Library/Application Support/Spencer/WindowsManager.sqlite"
    nonisolated static let query = """
        SELECT p.ZNAME, m.ZUUID FROM ZWMPROFILE p JOIN ZWMMONITOR m ON m.ZPROFILE = p.Z_PK \
        WHERE p.ZNAME IS NOT NULL AND m.ZUUID IS NOT NULL;
        """

    /// `sqlite3 -separator "\t"` output: one `name<TAB>uuid` line per display of a layout.
    nonisolated static func parse(_ output: String) -> SpencerLayoutDisplays {
        var displays: [String: Set<String>] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let uuid = parts[1].trimmingCharacters(in: .whitespaces).uppercased()
            guard !parts[0].isEmpty, !uuid.isEmpty else { continue }
            displays[String(parts[0]), default: []].insert(uuid)
        }
        return SpencerLayoutDisplays(displays: displays)
    }

    /// A layout can be restored when one of its displays is connected (Spencer puts the windows
    /// of a missing display on the others); an unknown one always can (spec SL-12).
    func isAvailable(_ layout: String, connected: Set<String>) -> Bool {
        guard let needed = displays[layout], !needed.isEmpty else { return true }
        return !needed.isDisjoint(with: connected)
    }

    /// Made for exactly these displays; the built-in one may be extra, for a layout saved with the
    /// lid closed (spec SL-13).
    func fits(_ layout: String, connected: Set<String>, builtin: Set<String>) -> Bool {
        guard let needed = displays[layout], !needed.isEmpty else { return displays.isEmpty }
        return needed.isSubset(of: connected) && connected.subtracting(needed).isSubset(of: builtin)
    }

    /// The layouts to offer for the displays connected now (spec SL-13): the one remembered for this
    /// setup, and the ones that fit its displays unless they are remembered for another setup (that
    /// is where they belong, whatever Spencer saved with them). When none is left, every layout with
    /// one of its displays here (SL-12), so the menu is never all grey.
    func available(_ layouts: [String], in setup: DisplaySetup?, assignments: [String: String]) -> Set<String> {
        guard let setup else { return Set(layouts) }
        let mine = assignments[setup.key]
        let elsewhere = Set(assignments.filter { $0.key != setup.key }.values).subtracting([mine].compactMap { $0 })
        let strict = layouts.filter { layout in
            layout == mine || (!elsewhere.contains(layout) && fits(layout, connected: setup.uuids, builtin: setup.builtin))
        }
        guard strict.isEmpty else { return Set(strict) }
        return Set(layouts.filter { isAvailable($0, connected: setup.uuids) })
    }

    /// The layout made for these displays and not remembered for another setup, in the menu's order
    /// (spec SL-9, SL-13).
    func matching(_ setup: DisplaySetup, assignments: [String: String], order: [String]) -> String? {
        guard !setup.uuids.isEmpty else { return nil }
        let names = order.isEmpty ? displays.keys.sorted() : order
        let elsewhere = Set(assignments.filter { $0.key != setup.key }.values)
        return names.first { name in
            displays[name] != nil && !elsewhere.contains(name)
                && fits(name, connected: setup.uuids, builtin: setup.builtin)
        }
    }

    /// Reads the database read-only; nil when it cannot be read.
    nonisolated static func load() -> SpencerLayoutDisplays? {
        guard FileManager.default.isReadableFile(atPath: databasePath),
              let result = ProcessRunner.run("/usr/bin/sqlite3", ["-readonly", "-separator", "\t", databasePath, query], timeout: 5),
              result.succeeded
        else { return nil }
        return parse(String(bytes: result.output, encoding: .utf8) ?? "")
    }
}
