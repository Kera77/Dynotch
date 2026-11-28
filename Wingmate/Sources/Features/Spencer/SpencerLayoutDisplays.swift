import Foundation

/// Which displays each Spencer layout was made for, read from Spencer's own database without
/// changing it (spec SL-8): greys the layouts whose displays are not all here (SL-7) and picks the
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

    /// The layout made for exactly the connected displays, in the menu's order.
    func matching(_ connected: Set<String>, order: [String]) -> String? {
        guard !connected.isEmpty else { return nil }
        let names = order.isEmpty ? displays.keys.sorted() : order
        return names.first { displays[$0] == connected }
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
