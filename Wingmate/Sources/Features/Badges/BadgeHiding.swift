import Foundation

/// How long a badge stays out of the notch (spec B-11).
enum BadgeHide: Codable, Equatable, Sendable {
    /// Until a moment (an hour, a day from hiding).
    case until(Date)
    /// Until a new message: the badge grows past what it showed when hidden, or goes away first.
    case untilNew(String)
    /// Until it is turned back on in the settings.
    case always

    /// The choices offered under a badge, in order.
    enum Choice: String, CaseIterable, Identifiable, Sendable {
        case hour = "For 1 Hour"
        case day = "For 1 Day"
        case untilNew = "Until a New Message"
        case always = "Until I Show It Again"

        var id: String { rawValue }
    }

    static func make(_ choice: Choice, label: String, now: Date) -> BadgeHide {
        switch choice {
        case .hour: .until(now.addingTimeInterval(3600))
        case .day: .until(now.addingTimeInterval(86400))
        case .untilNew: .untilNew(label)
        case .always: .always
        }
    }

    /// The settings' line for a hidden badge.
    func description(now: Date) -> String {
        switch self {
        case .until(let date):
            let sameDay = Calendar.current.isDate(date, inSameDayAs: now)
            return "Hidden until " + date.formatted(date: sameDay ? .omitted : .abbreviated, time: .shortened)
        case .untilNew: return "Hidden until a new message"
        case .always: return "Hidden"
        }
    }

    /// The hidings still in force: a time passed, or a new message (or no badge at all) ends one.
    static func remaining(_ hidden: [String: BadgeHide], labels: [String: String], now: Date) -> [String: BadgeHide] {
        hidden.filter { bundleID, hide in
            switch hide {
            case .until(let date): return date > now
            case .untilNew(let label):
                guard let current = labels[bundleID] else { return false }
                return !BadgeTracker.isNew(previous: label, current: current)
            case .always: return true
            }
        }
    }
}
