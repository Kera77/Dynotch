@testable import Dynotch
import Foundation
import SQLite3
import Testing

/// Records updated in place.
struct V054Tests {
    @Test func recordUpdatedInPlaceIsFoundAgain() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("V054-\(UUID().uuidString).db").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        var handle: OpaquePointer?
        #expect(sqlite3_open(path, &handle) == SQLITE_OK)
        let setup = """
        CREATE TABLE app (app_id INTEGER PRIMARY KEY, identifier TEXT);
        CREATE TABLE record (rec_id INTEGER PRIMARY KEY, app_id INTEGER, data BLOB, request_last_date REAL, delivered_date REAL);
        INSERT INTO app VALUES (1, 'app.zen-browser.zen');
        INSERT INTO record VALUES (5, 1, x'00', 100, 100);
        INSERT INTO record VALUES (6, 1, x'00', 110, 110);
        """
        #expect(sqlite3_exec(handle, setup, nil, nil, nil) == SQLITE_OK)

        let database = try NotificationDatabase(path: path)
        #expect(database.lastDelivered() == 110)
        #expect(try database.records(updatedAfter: 110, upTo: 6).isEmpty)
        // Zen replaces its notification for the same chat: record 5 is delivered again.
        #expect(sqlite3_exec(handle, "UPDATE record SET delivered_date = 120, request_last_date = 120 WHERE rec_id = 5", nil, nil, nil)
            == SQLITE_OK)
        #expect(try database.records(updatedAfter: 110, upTo: 6).map(\.id) == [5])
        #expect(database.lastDelivered() == 120)
        sqlite3_close(handle)
    }

    @Test func badgeListHeightFollowsItsNotificationsUpToFive() {
        func row(_ id: Int64, _ sender: String) -> BadgeNotificationRow {
            BadgeNotificationRow(id: id, sender: sender, detail: "m", date: Date())
        }
        #expect(IndicatorLayout.badgeDropdownHeight(rows: []) == 34)
        // Anna twice, Béla once: two name lines, three messages (spec B-10b).
        let rows = [row(1, "Anna"), row(2, "Béla"), row(3, "Anna")]
        #expect(BadgeNotificationRow.bySender(rows, limit: 5).map(\.sender) == ["Anna", "Béla"])
        #expect(BadgeNotificationRow.bySender(rows, limit: 5).first?.rows.map(\.id) == [1, 3])
        #expect(IndicatorLayout.badgeDropdownHeight(rows: rows) == CGFloat(8 + 2 * 20 + 3 * 18))
        let many = (0..<12).map { row(Int64($0), "Anna") }
        // All twelve are in the list; it stops growing at its limit and scrolls (spec B-10e).
        #expect(IndicatorLayout.badgeContentHeight(rows: many) == CGFloat(8 + 20 + 12 * 18))
        #expect(IndicatorLayout.badgeDropdownHeight(rows: many) == IndicatorLayout.badgeDropdownMaxHeight)
    }
}
