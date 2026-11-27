import Foundation

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
