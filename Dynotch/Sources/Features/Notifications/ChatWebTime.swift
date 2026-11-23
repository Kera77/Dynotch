import Foundation

/// The Home list's time of a Google Chat message as a date (spec GW-22): "4 perc", "2 óra",
/// "12:30", "Tegnap". Days and dates further back give nil.
enum ChatWebTime {
    static func date(from text: String, now: Date, calendar: Calendar = .current) -> Date? {
        let parts = text.split(separator: " ").map(String.init)
        if parts.count == 2, let number = Int(parts[0]) {
            switch parts[1] {
            case "perc", "min", "mins": return now.addingTimeInterval(-Double(number) * 60)
            case "óra", "hr", "hrs", "hour", "hours": return now.addingTimeInterval(-Double(number) * 3600)
            default: return nil
            }
        }
        if ["Most", "Now", "Just now"].contains(text) { return now }
        if ["Tegnap", "Yesterday"].contains(text) { return calendar.date(byAdding: .day, value: -1, to: now) }
        let clock = text.split(separator: ":")
        guard clock.count == 2, let hour = Int(clock[0]), let minute = Int(clock[1].prefix(2)),
              (0..<24).contains(hour), (0..<60).contains(minute)
        else { return nil }
        let afternoon = clock[1].lowercased().hasSuffix("pm") && hour < 12
        let date = calendar.date(bySettingHour: hour + (afternoon ? 12 : 0), minute: minute, second: 0, of: now)
        return date.map { $0 > now ? $0.addingTimeInterval(-86_400) : $0 }
    }
}
