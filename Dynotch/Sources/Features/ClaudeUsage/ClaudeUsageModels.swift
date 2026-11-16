import Foundation

/// One usage limit of the Claude subscription (spec CL-2).
struct UsageLimit: Identifiable, Equatable, Sendable {
    /// Key in the usage response, e.g. "five_hour", "seven_day", "seven_day_opus".
    let id: String
    let title: String
    /// Percent used, 0…100.
    let utilization: Double
    let resetsAt: Date?

    var level: UsageLevel { UsageLevel(utilization: utilization) }
}

enum UsageLevel: Equatable, Sendable {
    case normal
    /// From 70 %.
    case high
    /// From 90 %.
    case critical

    init(utilization: Double) {
        switch utilization {
        case 90...: self = .critical
        case 70...: self = .high
        default: self = .normal
        }
    }
}

/// Reads the usage response (the one Claude Code's `/usage` shows).
enum ClaudeUsageParser {
    struct InvalidResponse: Error {}

    static func limits(from data: Data) throws -> [UsageLimit] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw InvalidResponse() }
        // Current responses list every limit (session, weekly, per model) in "limits".
        if let list = json["limits"] as? [[String: Any]] {
            let parsed = list.compactMap(limit(fromListEntry:))
            if !parsed.isEmpty { return parsed.sorted { order(of: $0) < order(of: $1) } }
        }
        return legacyLimits(from: json)
    }

    /// One entry of "limits": {kind, group, percent, resets_at, is_active, severity}.
    static func limit(fromListEntry entry: [String: Any]) -> UsageLimit? {
        guard let percent = (entry["percent"] as? NSNumber)?.doubleValue else { return nil }
        if let active = entry["is_active"] as? Bool, !active { return nil }
        let kind = entry["kind"] as? String ?? ""
        let group = entry["group"] as? String ?? ""
        let id = [kind, group].filter { !$0.isEmpty }.joined(separator: ":")
        return UsageLimit(
            id: id.isEmpty ? UUID().uuidString : id,
            title: title(kind: kind, group: group),
            utilization: min(max(percent, 0), 100),
            resetsAt: (entry["resets_at"] as? String).flatMap(date(from:))
        )
    }

    /// "Session (5 hr)", "Weekly (7 day)", otherwise the model or group name with "limit".
    static func title(kind: String, group: String) -> String {
        let words = (kind + " " + group).lowercased()
        let isSession = words.contains("five_hour") || words.contains("5h") || words.contains("session")
        let isWeekly = words.contains("seven_day") || words.contains("7d") || words.contains("week")
        let name = group.isEmpty ? kind : group
        let generic: Set<String> = ["", "all", "overall", "default", "total", "session", "weekly", "five_hour", "seven_day"]
        if generic.contains(name.lowercased()) {
            if isSession { return "Session (5 hr)" }
            if isWeekly { return "Weekly (7 day)" }
        }
        let pretty = name.split(whereSeparator: { $0 == "_" || $0 == "-" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        return "\(pretty) limit"
    }

    /// Older responses: "five_hour", "seven_day" and "seven_day_<model>" objects.
    private static func legacyLimits(from json: [String: Any]) -> [UsageLimit] {
        let limits = json.compactMap { key, value -> UsageLimit? in
            guard !key.contains("oauth"), !key.contains("extra"),
                  let entry = value as? [String: Any],
                  let utilization = (entry["utilization"] as? NSNumber)?.doubleValue
            else { return nil }
            return UsageLimit(
                id: key,
                title: title(for: key),
                utilization: min(max(utilization, 0), 100),
                resetsAt: (entry["resets_at"] as? String).flatMap(date(from:))
            )
        }
        return limits.sorted { order(of: $0) < order(of: $1) }
    }

    /// The labels (not the numbers) of the "limits" entries, for the diagnostics log.
    static func labels(of data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        let limits = (json["limits"] as? [[String: Any]] ?? []).map {
            "kind=\($0["kind"] as? String ?? "-") group=\($0["group"] as? String ?? "-") "
                + "active=\($0["is_active"] as? Bool ?? false) severity=\($0["severity"] as? String ?? "-")"
        }
        return "limits: " + limits.joined(separator: "; ")
    }

    /// Shape of the response for the diagnostics log: keys and value types, no values.
    static func structure(of data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return "not JSON (\(data.count) bytes)" }
        return describe(json, depth: 0)
    }

    private static func describe(_ value: Any, depth: Int) -> String {
        switch value {
        case let dictionary as [String: Any]:
            guard depth < 4 else { return "{…}" }
            let fields = dictionary.keys.sorted().map { "\($0): \(describe(dictionary[$0] as Any, depth: depth + 1))" }
            return "{" + fields.joined(separator: ", ") + "}"
        case let array as [Any]:
            guard let first = array.first else { return "[]" }
            return "[\(array.count) × \(describe(first, depth: depth + 1))]"
        case is NSNull:
            return "null"
        case let number as NSNumber:
            return CFGetTypeID(number) == CFBooleanGetTypeID() ? "bool" : "number"
        case is String:
            return "string"
        default:
            return "?"
        }
    }

    static func title(for key: String) -> String {
        switch key {
        case "five_hour": return "Session (5 hr)"
        case "seven_day": return "Weekly (7 day)"
        default:
            let model = key.replacingOccurrences(of: "seven_day_", with: "")
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
            return "\(model) limit"
        }
    }

    /// Session first, then weekly, then the rest by name.
    private static func order(of limit: UsageLimit) -> String {
        if limit.id == "five_hour" || limit.title.hasPrefix("Session") { return "0" }
        if limit.id == "seven_day" || limit.title.hasPrefix("Weekly") { return "1" }
        return "2" + limit.title
    }

    static func date(from text: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }
        return ISO8601DateFormatter().date(from: text)
    }
}

/// When to warn about usage (spec CL-5): from 70 %, again at every further 10 %, once per limit
/// and reset period.
enum UsageAlerts {
    static let threshold: Double = 70

    static func bucket(for utilization: Double) -> Int? {
        guard utilization >= threshold else { return nil }
        return min(100, Int(utilization / 10) * 10)
    }

    /// Remembers the limit, its reset period and its current 10 % step.
    static func dismissMarker(for limit: UsageLimit) -> String {
        "\(key(for: limit))|\(Int(limit.utilization / 10))"
    }

    /// Hidden while the same limit stays in the same period and has not reached a higher 10 % step.
    static func isDismissed(_ limit: UsageLimit, marker: String?) -> Bool {
        guard let marker, let separator = marker.lastIndex(of: "|"),
              let step = Int(marker[marker.index(after: separator)...])
        else { return false }
        return String(marker[..<separator]) == key(for: limit) && Int(limit.utilization / 10) <= step
    }

    static func key(for limit: UsageLimit) -> String {
        "\(limit.id)|\(Int(limit.resetsAt?.timeIntervalSince1970 ?? 0))"
    }

    /// The limits to warn about now, and the updated record of what was warned about.
    static func alerts(for limits: [UsageLimit], notified: [String: Int]) -> (due: [UsageLimit], notified: [String: Int]) {
        var updated: [String: Int] = [:]
        var due: [UsageLimit] = []
        for limit in limits {
            let key = key(for: limit)
            let previous = notified[key] ?? 0
            guard let bucket = bucket(for: limit.utilization) else {
                if previous > 0 { updated[key] = previous }
                continue
            }
            if bucket > previous { due.append(limit) }
            updated[key] = max(bucket, previous)
        }
        return (due, updated)
    }

    /// "today 14:30", "tomorrow 9:00", "Tuesday, Nov 17 9:00"
    static func resetText(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return "today \(time)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "tomorrow \(time)"
        }
        return "\(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) \(time)"
    }
}
