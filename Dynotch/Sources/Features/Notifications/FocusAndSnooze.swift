import Foundation

/// Whether a macOS Focus is on, and which, from the Focus files (needs Full Disk Access, which
/// the notifications need anyway). The public API is closed to apps signed like Dynotch
/// (spec E-20).
enum MacFocus {
    private static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb/DB")
    }

    /// The active Focus's name ("Focus" if it has none); nil when no Focus is on or the files
    /// cannot be read.
    nonisolated static func current() -> String? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("Assertions.json")),
              let root = try? JSONSerialization.jsonObject(with: data)
        else { return nil }
        guard let mode = activeMode(in: root) else { return nil }
        return name(of: mode) ?? "Focus"
    }

    /// The mode of the first active assertion.
    nonisolated static func activeMode(in root: Any) -> String? {
        guard let records = find("storeAssertionRecords", in: root) as? [[String: Any]], let first = records.first else { return nil }
        return find("assertionDetailsModeIdentifier", in: first) as? String ?? "focus"
    }

    nonisolated private static func name(of mode: String) -> String? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("ModeConfigurations.json")),
              let root = try? JSONSerialization.jsonObject(with: data),
              let configuration = find(mode, in: root) as? [String: Any]
        else { return nil }
        return (configuration["mode"] as? [String: Any])?["name"] as? String
    }

    nonisolated static func find(_ key: String, in value: Any) -> Any? {
        if let dictionary = value as? [String: Any] {
            if let found = dictionary[key] { return found }
            for nested in dictionary.values { if let found = find(key, in: nested) { return found } }
        } else if let array = value as? [Any] {
            for nested in array { if let found = find(key, in: nested) { return found } }
        }
        return nil
    }
}

/// A notification put off until later (spec E-19).
struct SnoozedNotification: Sendable {
    let notification: AppNotification
    let until: Date
}

enum SnoozeChoice: CaseIterable, Sendable {
    case hour
    case evening
    case tomorrow

    var title: String {
        switch self {
        case .hour: "Remind Me in 1 Hour"
        case .evening: "This Evening (18:00)"
        case .tomorrow: "Tomorrow Morning (9:00)"
        }
    }

    func date(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .hour:
            return now.addingTimeInterval(3600)
        case .evening:
            let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
            return evening > now ? evening : evening.addingTimeInterval(86_400)
        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        }
    }
}
