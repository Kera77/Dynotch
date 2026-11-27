import EventKit
import Foundation

/// How often a reminder repeats, as the Reminders app offers it (spec R-14).
enum ReminderRepeat: String, CaseIterable, Sendable {
    case never, daily, weekdays, weekly, biweekly, monthly, yearly
    /// A rule set in the Reminders app that these choices don't cover: kept as it is.
    case custom

    var title: String {
        switch self {
        case .never: "Never"
        case .daily: "Daily"
        case .weekdays: "Weekdays"
        case .weekly: "Weekly"
        case .biweekly: "Every 2 Weeks"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .custom: "Custom"
        }
    }

    static func from(_ rules: [EKRecurrenceRule]?) -> ReminderRepeat {
        guard let rules, !rules.isEmpty else { return .never }
        guard rules.count == 1, let rule = rules.first, rule.recurrenceEnd == nil else { return .custom }
        let days = Set(rule.daysOfTheWeek?.map(\.dayOfTheWeek.rawValue) ?? [])
        switch (rule.frequency, rule.interval) {
        case (.daily, 1): return .daily
        case (.weekly, 1) where days == Set(2...6): return .weekdays
        case (.weekly, 1) where days.isEmpty: return .weekly
        case (.weekly, 2) where days.isEmpty: return .biweekly
        case (.monthly, 1): return .monthly
        case (.yearly, 1): return .yearly
        default: return .custom
        }
    }

    var rule: EKRecurrenceRule? {
        switch self {
        case .never, .custom: nil
        case .daily: EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekdays:
            EKRecurrenceRule(
                recurrenceWith: .weekly, interval: 1,
                daysOfTheWeek: [.monday, .tuesday, .wednesday, .thursday, .friday].map { EKRecurrenceDayOfWeek($0) },
                daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil
            )
        case .weekly: EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .biweekly: EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil)
        case .monthly: EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case .yearly: EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        }
    }
}

/// An alert before the due time, besides the one at it (spec R-14): minutes before it.
enum EarlyReminder: Int, CaseIterable, Sendable {
    case none = -1
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case oneDay = 1440

    var title: String {
        switch self {
        case .none: "None"
        case .fiveMinutes: "5 Minutes Before"
        case .fifteenMinutes: "15 Minutes Before"
        case .thirtyMinutes: "30 Minutes Before"
        case .oneHour: "1 Hour Before"
        case .oneDay: "1 Day Before"
        }
    }

    /// The closest choice to an alarm's offset (seconds, negative before the due time).
    static func from(offset: TimeInterval) -> EarlyReminder {
        let minutes = Int((-offset / 60).rounded())
        return allCases.filter { $0 != .none }.min { abs($0.rawValue - minutes) < abs($1.rawValue - minutes) } ?? .none
    }
}

/// What the details panel edits (spec R-14). Flags, tags, places, images and "when messaging"
/// are not reachable through EventKit, so they are left to the Reminders app.
struct ReminderDetails: Equatable, Sendable {
    var title: String
    var notes: String
    var url: String
    var hasDate: Bool
    var hasTime: Bool
    var due: Date
    var repeats: ReminderRepeat
    var early: EarlyReminder
    var listID: String
    /// 0 none, 9 low, 5 medium, 1 high (EventKit's scale).
    var priority: Int

    static let priorities: [(value: Int, title: String)] = [(0, "None"), (9, "Low"), (5, "Medium"), (1, "High")]

    /// EventKit stores 1…4 as high, 5 medium, 6…9 low.
    nonisolated static func normalizedPriority(_ value: Int) -> Int {
        switch value {
        case 1...4: 1
        case 5: 5
        case 6...9: 9
        default: 0
        }
    }

    /// The due date's parts: with the time, or the day only.
    nonisolated func dueComponents(calendar: Calendar = .current) -> DateComponents? {
        guard hasDate else { return nil }
        let parts: Set<Calendar.Component> = hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        return calendar.dateComponents(parts, from: due)
    }
}

extension RemindersStore {
    func details(for id: String) -> ReminderDetails? {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return nil }
        let components = reminder.dueDateComponents
        let due = components.flatMap { Calendar.current.date(from: $0) }
        let early = reminder.alarms?.compactMap { $0.absoluteDate == nil ? $0.relativeOffset : nil }.first
        return ReminderDetails(
            title: reminder.title ?? "", notes: reminder.notes ?? "", url: reminder.url?.absoluteString ?? "",
            hasDate: due != nil, hasTime: components?.hour != nil,
            due: due ?? Self.nextFullHour(), repeats: ReminderRepeat.from(reminder.recurrenceRules),
            early: early.map(EarlyReminder.from(offset:)) ?? .none,
            listID: reminder.calendar?.calendarIdentifier ?? "", priority: ReminderDetails.normalizedPriority(reminder.priority)
        )
    }

    /// Writes only what changed, so the Reminders app's own settings stay (spec R-14).
    func save(_ details: ReminderDetails, original: ReminderDetails, id: String) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
        applyTexts(details, original: original, to: reminder)
        if details.listID != original.listID, let list = store.calendar(withIdentifier: details.listID) { reminder.calendar = list }
        let dueChanged = details.hasDate != original.hasDate || details.hasTime != original.hasTime || details.due != original.due
        if dueChanged { reminder.dueDateComponents = details.dueComponents() }
        if details.repeats != original.repeats, details.repeats != .custom {
            reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
            // A repeating reminder needs a due date.
            if let rule = details.repeats.rule, details.hasDate { reminder.addRecurrenceRule(rule) }
        }
        if dueChanged || details.early != original.early { setAlarms(of: reminder, details) }
        do {
            try store.save(reminder, commit: true)
            errorMessage = nil
            log("details saved")
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
            log("details save failed: \(error)")
        }
        reload()
    }

    private func applyTexts(_ details: ReminderDetails, original: ReminderDetails, to reminder: EKReminder) {
        let title = details.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if details.title != original.title, !title.isEmpty { reminder.title = title }
        if details.notes != original.notes { reminder.notes = details.notes.isEmpty ? nil : details.notes }
        if details.url != original.url { reminder.url = URL(string: details.url.trimmingCharacters(in: .whitespaces)) }
        if details.priority != original.priority { reminder.priority = details.priority }
    }

    /// Like the Reminders app: an alert at the due time when it has one, and the early one.
    private func setAlarms(of reminder: EKReminder, _ details: ReminderDetails) {
        reminder.alarms?.forEach { reminder.removeAlarm($0) }
        guard details.hasDate, details.hasTime, let components = details.dueComponents(),
              let due = Calendar.current.date(from: components)
        else { return }
        reminder.addAlarm(EKAlarm(absoluteDate: due))
        if details.early != .none {
            reminder.addAlarm(EKAlarm(relativeOffset: -Double(details.early.rawValue) * 60))
        }
    }

    nonisolated static func nextFullHour(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .hour, for: date)?.end ?? date
    }
}
