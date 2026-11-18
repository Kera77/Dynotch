@testable import Dynotch
import Foundation
import SQLite3
import Testing

/// Records updated in place, the Focus Dynotch ignores.
struct V054Tests {
    @Test func ignoredFocusMatchesItsNameLoosely() {
        #expect(NotificationService.isIgnored("Dynotch", ignored: "dynotch "))
        #expect(NotificationService.isIgnored("Munka", ignored: "munka"))
        #expect(!NotificationService.isIgnored("Work", ignored: "Dynotch"))
        #expect(!NotificationService.isIgnored("Dynotch", ignored: ""))
    }

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
        #expect(IndicatorLayout.badgeDropdownHeight(count: 0) == 34)
        #expect(IndicatorLayout.badgeDropdownHeight(count: 2) == CGFloat(8 + 2 * 36))
        #expect(IndicatorLayout.badgeDropdownHeight(count: 12) == CGFloat(8 + 5 * 36))
    }
}
