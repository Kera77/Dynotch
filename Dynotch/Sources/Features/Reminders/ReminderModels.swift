import Foundation

struct ReminderList: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let color: CalendarColor
}

struct ReminderItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let listID: String
    let due: Date?
    /// The due date has a time of day, not just a day.
    let dueHasTime: Bool
    /// EventKit priority: 1 (high) … 9 (low), 0 = none.
    let priority: Int
    let isCompleted: Bool
    let created: Date?

    func isOverdue(at now: Date, calendar: Calendar = .current) -> Bool {
        guard let due, !isCompleted else { return false }
        return dueHasTime ? due < now : due < calendar.startOfDay(for: now)
    }
}

enum ReminderSort: String, CaseIterable, Sendable {
    case due
    case priority
    case title

    var title: String {
        switch self {
        case .due: "Due Date"
        case .priority: "Priority"
        case .title: "Title"
        }
    }
}

/// How near the due date is: the pill's colour (spec R-9).
enum DueUrgency: Equatable, Sendable {
    case overdue
    case today
    case tomorrow
    case later
}

/// Pure reminder logic: sorting, upcoming, due texts.
enum ReminderLogic {
    static func urgency(of item: ReminderItem, now: Date, calendar: Calendar = .current) -> DueUrgency? {
        guard let due = item.due else { return nil }
        if item.isOverdue(at: now, calendar: calendar) { return .overdue }
        if calendar.isDate(due, inSameDayAs: now) { return .today }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(due, inSameDayAs: tomorrow) {
            return .tomorrow
        }
        return .later
    }

    /// Upcoming: incomplete reminders due before the end of this many days (overdue included).
    static let upcomingDays = 7

    static func sorted(_ items: [ReminderItem], by sort: ReminderSort) -> [ReminderItem] {
        items.sorted { lhs, rhs in
            switch sort {
            case .due:
                switch (lhs.due, rhs.due) {
                case let (left?, right?) where left != right: return left < right
                case (.some, nil): return true
                case (nil, .some): return false
                default: return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                }
            case .priority:
                let left = lhs.priority == 0 ? 10 : lhs.priority
                let right = rhs.priority == 0 ? 10 : rhs.priority
                if left != right { return left < right }
                return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            case .title:
                return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
        }
    }

    static func upcoming(_ items: [ReminderItem], now: Date, calendar: Calendar = .current) -> [ReminderItem] {
        guard let end = calendar.date(byAdding: .day, value: upcomingDays, to: calendar.startOfDay(for: now)) else { return [] }
        return items.filter { item in
            guard let due = item.due, !item.isCompleted else { return false }
            return due < end
        }
    }

    /// "Overdue · yesterday", "today 14:00", "tomorrow", "Thursday", "Nov 30"
    static func dueText(for item: ReminderItem, now: Date, calendar: Calendar = .current) -> String? {
        guard let due = item.due else { return nil }
        let time = item.dueHasTime ? " " + due.formatted(date: .omitted, time: .shortened) : ""
        let today = calendar.startOfDay(for: now)
        let dueDay = calendar.startOfDay(for: due)
        let days = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        let day: String
        switch days {
        case 0: day = "today"
        case 1: day = "tomorrow"
        case -1: day = "yesterday"
        case 2...6: day = due.formatted(.dateTime.weekday(.wide))
        default: day = due.formatted(.dateTime.month(.abbreviated).day())
        }
        let text = day + time
        return item.isOverdue(at: now, calendar: calendar) ? "Overdue · " + text : text
    }
}

/// What the quick-add field understood (spec R-3).
struct ParsedReminder: Equatable, Sendable {
    var title: String
    var due: Date?
    var dueHasTime: Bool
    /// List named with "@Lista" in the text.
    var listID: String?
}

/// Reads a date and an "@list" from the quick-add text (spec R-3).
enum ReminderParser {
    static func parse(
        _ text: String,
        lists: [ReminderList],
        now: Date,
        autoToday: Bool,
        removeDate: Bool,
        calendar: Calendar = .current
    ) -> ParsedReminder {
        var title = text
        var listID: String?

        // "@Munka" picks a list by name (prefix, case-insensitive) and is removed from the title.
        if let range = title.range(of: #"@[\p{L}\p{N}_-]+"#, options: .regularExpression) {
            let name = title[range].dropFirst().lowercased()
            if let list = lists.first(where: { $0.title.lowercased().hasPrefix(name) }) {
                listID = list.id
                title.removeSubrange(range)
            }
        }

        var due: Date?
        var hasTime = false
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
           let match = detector.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let date = match.date,
           let range = Range(match.range, in: title) {
            let matched = String(title[range])
            let timePattern = #"\d{1,2}([:.]\d{2})|\d\s?(am|pm)|\bdélben\b"#
            hasTime = matched.range(of: timePattern, options: [.regularExpression, .caseInsensitive]) != nil
            due = hasTime ? date : calendar.startOfDay(for: date)
            if removeDate {
                var withoutDate = title
                withoutDate.removeSubrange(range)
                // The detector may swallow words like "Lunch": never leave an empty title.
                if !clean(withoutDate).isEmpty { title = withoutDate }
            }
        }
        if due == nil, autoToday {
            due = calendar.startOfDay(for: now)
            hasTime = false
        }

        let cleaned = clean(title)
        return ParsedReminder(
            title: cleaned.isEmpty ? text.trimmingCharacters(in: .whitespaces) : cleaned,
            due: due, dueHasTime: hasTime, listID: listID
        )
    }

    /// Words left dangling at the end once a date is removed ("Call Anna on").
    private static let danglingWords: Set<String> = ["on", "at", "by", "in", "for", "due", "until", "next", "-"]

    private static func clean(_ title: String) -> String {
        let trimSet = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters.subtracting(["?", "!", ")"]))
        var words = title
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: trimSet)
            .split(separator: " ")
            .map(String.init)
        while words.count > 1, let last = words.last, danglingWords.contains(last.lowercased()) {
            words.removeLast()
        }
        return words.joined(separator: " ").trimmingCharacters(in: trimSet)
    }
}
