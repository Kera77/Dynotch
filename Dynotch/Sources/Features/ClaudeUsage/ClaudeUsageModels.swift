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

    private static func order(of limit: UsageLimit) -> String {
        switch limit.id {
        case "five_hour": "0"
        case "seven_day": "1"
        default: "2" + limit.title
        }
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
