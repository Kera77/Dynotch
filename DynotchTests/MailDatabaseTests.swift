@testable import Dynotch
import Foundation
import SQLite3
import Testing

/// Gmail's Primary label in Apple Mail's index, both ways Mail stores it (spec GM-16, GM-17).
struct MailDatabaseTests {
    private static let schema = """
    CREATE TABLE messages (sender INTEGER, subject INTEGER, date_received INTEGER, mailbox INTEGER,
        read INTEGER, deleted INTEGER, global_message_id INTEGER);
    CREATE TABLE message_global_data (message_id_header TEXT);
    CREATE TABLE addresses (address TEXT, comment TEXT);
    CREATE TABLE subjects (subject TEXT);
    CREATE TABLE mailboxes (url TEXT);
    CREATE TABLE labels (message_id INTEGER, mailbox_id INTEGER);
    INSERT INTO mailboxes (ROWID, url) VALUES (1, 'imap://G/INBOX'), (2, 'imap://G/Primary'),
        (3, 'imap://G/%5BGmail%5D/All%20Mail');
    """

    private func database(_ rows: String) throws -> String {
        let path = NSTemporaryDirectory() + "mail-\(UUID().uuidString).sqlite"
        var handle: OpaquePointer?
        #expect(sqlite3_open(path, &handle) == SQLITE_OK)
        #expect(sqlite3_exec(handle, Self.schema + rows, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(handle)
        return path
    }

    private func unread(_ path: String) throws -> Int {
        let info = MailAccountInfo(id: "G", name: "Gmail", isGmail: true)
        return try MailDatabase.read(accounts: [info], path: path, label: "Primary").accounts[0].unread
    }

    /// Mail keeps a copy of the message in the label's mailbox, sharing its global id.
    @Test func countsLabelCopies() throws {
        let path = try database("""
        INSERT INTO messages (ROWID, mailbox, read, deleted, global_message_id) VALUES
            (1, 1, 0, 0, 10), (2, 2, 0, 0, 10), (3, 1, 0, 0, 11), (4, 1, 1, 0, 12), (5, 2, 1, 0, 12);
        """)
        #expect(try unread(path) == 1)
    }

    /// One row in All Mail with its Inbox and Primary labels in the labels table.
    @Test func countsLabelsTable() throws {
        let path = try database("""
        INSERT INTO messages (ROWID, mailbox, read, deleted, global_message_id) VALUES (1, 3, 0, 0, 10), (2, 3, 0, 0, 11);
        INSERT INTO labels VALUES (1, 1), (1, 2), (2, 1);
        """)
        #expect(try unread(path) == 1)
    }

    /// No Inbox mail with the label: the whole Inbox counts (spec GM-17).
    @Test func unusedLabelCountsWholeInbox() throws {
        let path = try database("""
        INSERT INTO messages (ROWID, mailbox, read, deleted, global_message_id) VALUES (1, 1, 0, 0, 10), (2, 1, 0, 0, 11);
        """)
        #expect(try unread(path) == 2)
    }
}
