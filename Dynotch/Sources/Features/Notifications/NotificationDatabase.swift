import Foundation
import SQLite3

struct NotificationRecord {
    let id: Int64
    let appIdentifier: String
    let data: Data
}

struct NotificationDatabaseError: Error, CustomStringConvertible {
    let description: String
}

/// Read-only access to the Notification Center database (needs Full Disk Access).
final class NotificationDatabase {
    /// Known locations, newest macOS first.
    static var candidatePaths: [String] {
        var paths = [NSHomeDirectory() + "/Library/Group Containers/group.com.apple.usernoted/db2/db"]
        let legacy = NSTemporaryDirectory().replacingOccurrences(of: "/T/", with: "/0/")
            + "com.apple.notificationcenter/db2/db"
        paths.append(legacy)
        return paths
    }

    let path: String
    private var handle: OpaquePointer?

    init(path: String) throws {
        self.path = path
        var connection: OpaquePointer?
        let code = sqlite3_open_v2(path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard code == SQLITE_OK, let connection else {
            let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "code \(code)"
            sqlite3_close(connection)
            throw NotificationDatabaseError(description: "open failed: \(message)")
        }
        sqlite3_busy_timeout(connection, 50)
        handle = connection
        // Opening is lazy; make sure the table is really readable.
        _ = try maxRecordID()
    }

    deinit {
        sqlite3_close(handle)
    }

    func maxRecordID() throws -> Int64 {
        try query("SELECT IFNULL(MAX(rec_id), 0) FROM record") { sqlite3_column_int64($0, 0) }.first ?? 0
    }

    func records(after recordID: Int64) throws -> [NotificationRecord] {
        let sql = """
        SELECT r.rec_id, IFNULL(a.identifier, ''), r.data
        FROM record r LEFT JOIN app a ON a.app_id = r.app_id
        WHERE r.rec_id > ? ORDER BY r.rec_id LIMIT 50
        """
        return try query(sql, argument: recordID) { statement in
            NotificationRecord(
                id: sqlite3_column_int64(statement, 0),
                appIdentifier: Self.text(statement, 1),
                data: Self.blob(statement, 2)
            )
        }
    }

    func appIdentifiers() throws -> [String] {
        try query("SELECT identifier FROM app") { Self.text($0, 0) }
    }

    /// Table definitions and the key names of the newest record, for the diagnostics log.
    func diagnostics() -> String {
        var lines = ["path: \(path)"]
        do {
            let tables = try query("SELECT IFNULL(sql, name) FROM sqlite_master WHERE type = 'table'") { Self.text($0, 0) }
            lines.append(contentsOf: tables)
            lines.append("max rec_id: \(try maxRecordID())")
            let newest = try query("SELECT data FROM record ORDER BY rec_id DESC LIMIT 1") { Self.blob($0, 0) }
            lines.append("newest record " + (newest.first.map(NotificationParser.keySummary) ?? "none"))
            lines.append("apps: \(try appIdentifiers().sorted())")
            // How many of the recent records each app posted (no content).
            let counts = try query(
                """
                SELECT IFNULL(a.identifier, '?'), COUNT(*) FROM
                (SELECT app_id FROM record ORDER BY rec_id DESC LIMIT 2000) r
                LEFT JOIN app a ON a.app_id = r.app_id GROUP BY r.app_id ORDER BY COUNT(*) DESC
                """
            ) { "\(Self.text($0, 0)): \(sqlite3_column_int64($0, 1))" }
            lines.append("recent records per app: \(counts)")
            // Site and field names of the newest records of browsers and web apps (no content).
            let shared = try query(
                """
                SELECT a.identifier, r.data FROM record r JOIN app a ON a.app_id = r.app_id
                ORDER BY r.rec_id DESC LIMIT 400
                """
            ) { (Self.text($0, 0), Self.blob($0, 1)) }
            .filter { WebNotificationSource.isShared($0.0) || $0.0.lowercased().hasPrefix("com.apple.safari") }
            .prefix(25)
            for (identifier, data) in shared {
                let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] ?? [:]
                let request = (plist["req"] as? [String: Any]) ?? [:]
                lines.append(
                    "browser record \(identifier): site=\(WebNotificationSource.site(in: plist) ?? "-") "
                        + "keys=\(plist.keys.sorted()) req=\(request.keys.sorted())"
                )
            }
        } catch {
            lines.append("diagnostics failed: \(error)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func query<Row>(_ sql: String, argument: Int64? = nil, row: (OpaquePointer) -> Row) throws -> [Row] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw NotificationDatabaseError(description: "prepare failed: \(errorMessage)")
        }
        defer { sqlite3_finalize(statement) }
        if let argument {
            sqlite3_bind_int64(statement, 1, argument)
        }

        var rows: [Row] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_ROW {
                rows.append(row(statement))
            } else if code == SQLITE_DONE {
                return rows
            } else {
                throw NotificationDatabaseError(description: "step failed: \(errorMessage)")
            }
        }
    }

    private var errorMessage: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "no connection"
    }

    private static func text(_ statement: OpaquePointer, _ column: Int32) -> String {
        sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
    }

    private static func blob(_ statement: OpaquePointer, _ column: Int32) -> Data {
        guard let bytes = sqlite3_column_blob(statement, column) else { return Data() }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column)))
    }
}
