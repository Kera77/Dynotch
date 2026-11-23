import Foundation
import SQLite3

struct MailDatabaseError: Error, CustomStringConvertible {
    let description: String
}

/// Read-only access to Apple Mail's own index, "Envelope Index" (needs Full Disk Access): the
/// Inboxes' unread headers without asking Mail anything, so a huge Inbox never keeps Mail busy
/// (spec GM-13). Opened for one read, off the main thread, then closed.
final class MailDatabase {
    /// The newest `~/Library/Mail/V*/MailData/Envelope Index`.
    static var defaultPath: String? {
        let root = NSHomeDirectory() + "/Library/Mail"
        let versions = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
        let newest = versions
            .filter { $0.hasPrefix("V") }
            .compactMap { name in Int(name.dropFirst()).map { (name, $0) } }
            .max { $0.1 < $1.1 }
        return newest.map { root + "/" + $0.0 + "/MailData/Envelope Index" }
    }

    /// The columns read; a macOS update that changes them gives a clear error (spec GM-11).
    static let neededColumns: [String: Set<String>] = [
        "messages": ["sender", "subject", "date_received", "mailbox", "read", "deleted"],
        "addresses": ["address", "comment"],
        "subjects": ["subject"],
        "mailboxes": ["url"]
    ]

    private var handle: OpaquePointer?
    private var hasMessageIDs = false
    private var hasSubjectPrefix = false
    private var hasLabels = false

    init(path: String) throws {
        var connection: OpaquePointer?
        let code = sqlite3_open_v2(path, &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        guard code == SQLITE_OK, let connection else {
            let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "code \(code)"
            sqlite3_close(connection)
            throw MailDatabaseError(description: "open failed: \(message)")
        }
        sqlite3_busy_timeout(connection, 500)
        handle = connection
        try checkLayout()
    }

    deinit {
        sqlite3_close(handle)
    }

    private func columns(of table: String) throws -> Set<String> {
        Set(try query("PRAGMA table_info(\(table))") { Self.text($0, 1) })
    }

    private func checkLayout() throws {
        for (table, needed) in Self.neededColumns.sorted(by: { $0.key < $1.key }) {
            let found = try columns(of: table)
            let missing = needed.subtracting(found)
            guard missing.isEmpty else {
                // Only column names go to the log, never what the mail holds (spec GM-10).
                throw MailDatabaseError(description: "layout changed: \(table) lacks \(missing.sorted()) (has \(found.sorted()))")
            }
        }
        let messages = try columns(of: "messages")
        let globalData = try columns(of: "message_global_data")
        hasMessageIDs = messages.contains("global_message_id") && globalData.contains("message_id_header")
        hasSubjectPrefix = messages.contains("subject_prefix")
        hasLabels = try columns(of: "labels").isSuperset(of: ["message_id", "mailbox_id"])
    }

    /// Each account's Inbox mailbox, by account id.
    func inboxes() throws -> [String: Int64] {
        let rows = try query("SELECT ROWID, url FROM mailboxes") { (sqlite3_column_int64($0, 0), Self.text($0, 1)) }
        var result: [String: Int64] = [:]
        for (id, url) in rows {
            if let account = MailParser.inboxAccount(url: url), result[account] == nil { result[account] = id }
        }
        return result
    }

    /// Each account's mailbox for a label, by account id (spec GM-16).
    func labelBoxes(_ label: String) throws -> [String: Int64] {
        let rows = try query("SELECT ROWID, url FROM mailboxes") { (sqlite3_column_int64($0, 0), Self.text($0, 1)) }
        var result: [String: Int64] = [:]
        for (id, url) in rows {
            if let account = MailParser.labelAccount(url: url, label: label), result[account] == nil { result[account] = id }
        }
        return result
    }

    /// A message in mailbox ?n: Gmail keeps its mail once, in All Mail, and puts it in the Inbox
    /// and other mailboxes with a label.
    private func inBox(_ argument: Int) -> String {
        let labelled = hasLabels ? " OR m.ROWID IN (SELECT message_id FROM labels WHERE mailbox_id = ?\(argument))" : ""
        return "(m.mailbox = ?\(argument)\(labelled))"
    }

    /// Unread, not deleted messages of the Inbox; with a label box also in that label, as Gmail's
    /// Primary tab (spec GM-16).
    private func unreadWhere(label: Int64?) -> String {
        "m.read = 0 AND m.deleted = 0 AND \(inBox(1))" + (label == nil ? "" : " AND \(inBox(2))")
    }

    func unreadCount(inbox: Int64, label: Int64? = nil) throws -> Int {
        try query("SELECT COUNT(*) FROM messages m WHERE \(unreadWhere(label: label))", arguments: [inbox] + [label].compactMap { $0 }) {
            Int(sqlite3_column_int64($0, 0))
        }.first ?? 0
    }

    /// The newest unread headers of the Inbox; never the body (spec GM-2).
    func unreadRows(inbox: Int64, label: Int64? = nil, limit: Int) throws -> [MailRow] {
        let messageID = hasMessageIDs ? "IFNULL(g.message_id_header, '')" : "''"
        let prefix = hasSubjectPrefix ? "IFNULL(m.subject_prefix, '') || " : ""
        let join = hasMessageIDs ? "LEFT JOIN message_global_data g ON g.ROWID = m.global_message_id" : ""
        let sql = """
        SELECT \(messageID), IFNULL(a.address, ''), IFNULL(a.comment, ''), \(prefix)IFNULL(s.subject, ''), IFNULL(m.date_received, 0)
        FROM messages m
        LEFT JOIN addresses a ON a.ROWID = m.sender
        LEFT JOIN subjects s ON s.ROWID = m.subject
        \(join)
        WHERE \(unreadWhere(label: label))
        ORDER BY m.date_received DESC LIMIT \(limit)
        """
        return try query(sql, arguments: [inbox] + [label].compactMap { $0 }) { statement in
            MailRow(
                messageID: Self.text(statement, 0), address: Self.text(statement, 1), displayName: Self.text(statement, 2),
                subject: Self.text(statement, 3), received: sqlite3_column_double(statement, 4)
            )
        }
    }

    private func query<Row>(_ sql: String, arguments: [Int64] = [], row: (OpaquePointer) -> Row) throws -> [Row] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw MailDatabaseError(description: "prepare failed: \(errorMessage)")
        }
        defer { sqlite3_finalize(statement) }
        for (index, argument) in arguments.enumerated() { sqlite3_bind_int64(statement, Int32(index + 1), argument) }
        var rows: [Row] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_ROW {
                rows.append(row(statement))
            } else if code == SQLITE_DONE {
                return rows
            } else {
                throw MailDatabaseError(description: "step failed: \(errorMessage)")
            }
        }
    }

    private var errorMessage: String {
        handle.map { String(cString: sqlite3_errmsg($0)) } ?? "no connection"
    }

    private static func text(_ statement: OpaquePointer, _ column: Int32) -> String {
        sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
    }
}

extension MailDatabase {
    /// The chosen view of every known account: its Inbox's unread count and newest headers.
    /// Blocks: call it off the main thread.
    /// - Parameter label: a Gmail account with a mailbox of this name counts only the Inbox mail
    ///   that has it too (spec GM-16); without one, the whole Inbox.
    static func read(accounts infos: [MailAccountInfo], path: String, label: String = "") throws -> [MailAccount] {
        let database = try MailDatabase(path: path)
        let inboxes = try database.inboxes()
        let labels = label.trimmingCharacters(in: .whitespaces).isEmpty ? [:] : try database.labelBoxes(label)
        return try infos.map { info in
            guard let inbox = inboxes[info.id] else { return MailParser.account(info, unread: 0, rows: []) }
            let box = info.isGmail ? labels[info.id] : nil
            let unread = try database.unreadCount(inbox: inbox, label: box)
            let rows = unread > 0 ? try database.unreadRows(inbox: inbox, label: box, limit: MailParser.messageLimit) : []
            return MailParser.account(info, unread: unread, rows: rows)
        }
    }
}
