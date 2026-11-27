import Foundation
import Observation

/// What the tasks counter beside the notch shows (spec R-10).
struct TaskCount: Equatable, Sendable {
    let count: Int
    /// Due today (or overdue); otherwise every open task.
    let isToday: Bool
    /// Rows under the drop-down's header: the chosen list's when the tasks are in several lists (spec R-17).
    var listRows: Int?
    /// The tasks are in several lists: the header chooses between them (spec R-17).
    var isSplit = false
    /// Red with an overdue task, orange with one due within the hour (spec R-27).
    var tone: TaskTone = .normal
    /// The overdue tasks written in thin rows under the counter (spec R-26).
    var overdue: [ReminderItem] = []

    var rows: Int { listRows ?? count }

    var text: String {
        isToday ? "\(count) task\(count == 1 ? "" : "s") due today" : "\(count) open task\(count == 1 ? "" : "s")"
    }
}

/// The counter's colour (spec R-27).
enum TaskTone: Equatable, Sendable {
    case normal, soon, overdue
}

/// How long the × hides the counter (spec R-11).
enum TaskSnooze: Int, CaseIterable, Sendable {
    case quarterHour = 15
    case halfHour = 30
    case hour = 60
    case twoHours = 120
    case tomorrow = 0

    var title: String {
        switch self {
        case .quarterHour: "15 minutes"
        case .halfHour: "30 minutes"
        case .hour: "1 hour"
        case .twoHours: "2 hours"
        case .tomorrow: "Until tomorrow"
        }
    }

    func until(from now: Date, calendar: Calendar = .current) -> Date {
        guard self != .tomorrow else {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        }
        return now.addingTimeInterval(TimeInterval(rawValue * 60))
    }
}

enum TaskIndicatorLogic {
    /// Today's tasks (due today or overdue) if there are any, otherwise every open one.
    static func count(_ items: [ReminderItem], now: Date, calendar: Calendar = .current) -> TaskCount? {
        let today = todays(items, now: now, calendar: calendar)
        if !today.isEmpty { return TaskCount(count: today.count, isToday: true) }
        return items.isEmpty ? nil : TaskCount(count: items.count, isToday: false)
    }

    /// The tasks the counter counts, in the order the drop-down lists them (spec R-12).
    static func listed(_ items: [ReminderItem], now: Date, calendar: Calendar = .current) -> [ReminderItem] {
        let today = todays(items, now: now, calendar: calendar)
        return ReminderLogic.sorted(today.isEmpty ? items : today, by: .due)
    }

    private static func todays(_ items: [ReminderItem], now: Date, calendar: Calendar) -> [ReminderItem] {
        items.filter { item in
            item.isOverdue(at: now, calendar: calendar) || item.due.map { calendar.isDate($0, inSameDayAs: now) } == true
        }
    }

    /// The open tasks by list, in the lists' order: each list's tasks for today if it has any,
    /// otherwise all of its open ones (spec R-17, R-18).
    static func groups(_ items: [ReminderItem], lists: [ReminderList], now: Date, calendar: Calendar = .current) -> [TaskGroup] {
        let byList = Dictionary(grouping: items, by: \.listID)
        let known = lists.compactMap { list in
            byList[list.id].map { TaskGroup(listID: list.id, title: list.title, items: Self.listed($0, now: now, calendar: calendar)) }
        }
        let knownIDs = Set(lists.map(\.id))
        let others = items.filter { !knownIDs.contains($0.listID) }
        let other = TaskGroup(listID: "", title: "Other", items: Self.listed(others, now: now, calendar: calendar))
        return known + (others.isEmpty ? [] : [other])
    }

    /// The list shown first: the one with the nearest due date (overdue too), else the first (spec R-17).
    static func defaultGroup(_ groups: [TaskGroup]) -> TaskGroup? {
        let dated = groups.compactMap { group in group.items.compactMap(\.due).min().map { (group, $0) } }
        return dated.min { $0.1 < $1.1 }?.0 ?? groups.first
    }

    /// An hour before a timed due date the counter turns orange (spec R-27).
    static let soonLead: TimeInterval = 3600
    /// Later on an overdue task brings it back after an hour (spec R-26).
    static let laterDelay: TimeInterval = 3600

    /// Red with an overdue task, orange with one due within the hour, else white (spec R-27).
    static func tone(_ items: [ReminderItem], now: Date, calendar: Calendar = .current) -> TaskTone {
        if items.contains(where: { $0.isOverdue(at: now, calendar: calendar) }) { return .overdue }
        let soon = items.contains { item in
            guard item.dueHasTime, let due = item.due else { return false }
            return due > now && due.timeIntervalSince(now) <= soonLead
        }
        return soon ? .soon : .normal
    }

    /// The overdue tasks that stay under the notch: not put away with their X (until their due
    /// date changes) nor with Later for the hour (spec R-26). Oldest first.
    static func overdueNotices(
        _ items: [ReminderItem], now: Date, dismissed: [String: Double], later: [String: Date],
        calendar: Calendar = .current
    ) -> [ReminderItem] {
        items.filter { item in
            guard item.isOverdue(at: now, calendar: calendar), let due = item.due else { return false }
            if dismissed[item.id] == due.timeIntervalSince1970 { return false }
            return later[item.id].map { $0 <= now } ?? true
        }
        .sorted { ($0.due ?? now) < ($1.due ?? now) }
    }

    /// The next moment the colour or the overdue rows change by time alone.
    static func nextChange(
        _ items: [ReminderItem], now: Date, later: [String: Date], hiddenUntil: Date?, calendar: Calendar = .current
    ) -> Date? {
        var moments = Array(later.values) + [hiddenUntil].compactMap { $0 }
        for item in items {
            guard let due = item.due else { continue }
            if item.dueHasTime {
                moments += [due, due.addingTimeInterval(-soonLead)]
            } else if let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: due)) {
                moments.append(next)
            }
        }
        return moments.filter { $0 > now }.min()
    }

    /// The hidden counter comes back when its time is up or a task arrived meanwhile.
    static func showsAgain(hiddenUntil: Date, hiddenIDs: Set<String>, openIDs: [String], now: Date) -> Bool {
        hiddenUntil <= now || openIDs.contains { !hiddenIDs.contains($0) }
    }
}

/// One list's counted tasks in the counter's drop-down (spec R-17).
struct TaskGroup: Equatable, Sendable {
    let listID: String
    let title: String
    let items: [ReminderItem]
}

/// The tasks counter right of the closed notch: on or off, hidden for a while by its × (spec R-10, R-11).
@MainActor
@Observable
final class TaskIndicator {
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled); update() }
    }
    var snooze: TaskSnooze {
        didSet { defaults.set(snooze.rawValue, forKey: Key.snooze) }
    }
    private(set) var shown: TaskCount?
    /// The list chosen in the drop-down's header until it closes (spec R-17).
    var chosenListID: String? {
        didSet { if chosenListID != oldValue { update() } }
    }

    private enum Key {
        static let enabled = "taskIndicator"
        static let snooze = "taskIndicatorSnooze"
        static let hiddenUntil = "taskIndicatorHiddenUntil"
        static let hiddenIDs = "taskIndicatorHiddenIDs"
        static let dismissed = "taskIndicatorDismissedOverdue"
        static let later = "taskIndicatorLater"
    }

    private let store: RemindersStore
    private let defaults: UserDefaults
    @ObservationIgnored private var hiddenUntil: Date?
    @ObservationIgnored private var hiddenIDs: Set<String>
    /// Overdue tasks put away with their X, by the due date they had then (spec R-26).
    @ObservationIgnored private var dismissed: [String: Double]
    /// Overdue tasks put away with Later, until when (spec R-26).
    @ObservationIgnored private var later: [String: Date]
    @ObservationIgnored private var wakeAt: Date?
    @ObservationIgnored private var changes: ChangeObservation?
    @ObservationIgnored private var wake: Task<Void, Never>?

    init(store: RemindersStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        snooze = (defaults.object(forKey: Key.snooze) as? Int).flatMap(TaskSnooze.init(rawValue:)) ?? .hour
        hiddenUntil = defaults.object(forKey: Key.hiddenUntil) as? Date
        hiddenIDs = Set(defaults.stringArray(forKey: Key.hiddenIDs) ?? [])
        dismissed = defaults.dictionary(forKey: Key.dismissed) as? [String: Double] ?? [:]
        later = defaults.dictionary(forKey: Key.later) as? [String: Date] ?? [:]
        // Looks once the reminders have changed.
        changes = observeChanges { [store] in
            _ = store.access
            _ = store.open
            _ = store.completing
            _ = store.lists
        } onChange: { [weak self] in
            self?.update()
        }
        update()
    }

    private var openItems: [ReminderItem] {
        store.access == .granted ? store.open.filter { !store.completing.contains($0.id) } : []
    }

    /// The tasks under the counter's hover drop-down (spec R-12).
    var listed: [ReminderItem] { TaskIndicatorLogic.listed(openItems, now: Date()) }

    /// The counted tasks by list (spec R-17).
    var groups: [TaskGroup] { TaskIndicatorLogic.groups(openItems, lists: store.lists, now: Date()) }

    /// The list shown under the header: the chosen one, else the one due soonest (spec R-17).
    var selectedGroup: TaskGroup? {
        let all = groups
        return all.first { $0.listID == chosenListID } ?? TaskIndicatorLogic.defaultGroup(all)
    }

    /// Chooses the next or previous list in the drop-down's picker, stopping at either end (spec R-19).
    /// - Returns: whether the choice changed.
    @discardableResult
    func stepList(by offset: Int) -> Bool {
        let all = groups
        guard all.count > 1, let selected = selectedGroup,
              let index = all.firstIndex(where: { $0.listID == selected.listID }) else { return false }
        let target = min(max(index + offset, 0), all.count - 1)
        guard target != index else { return false }
        chosenListID = all[target].listID
        return true
    }

    /// Checked off from the drop-down.
    func complete(_ item: ReminderItem) {
        store.complete(item)
    }

    /// The ×: hidden for the chosen time, or until a new task arrives.
    func hide(now: Date = Date()) {
        hiddenUntil = snooze.until(from: now)
        hiddenIDs = Set(openItems.map(\.id))
        save()
        update(now: now)
    }

    /// Later on an overdue task: back under the notch in an hour (spec R-26).
    func remindLater(_ item: ReminderItem, now: Date = Date()) {
        later[item.id] = now.addingTimeInterval(TaskIndicatorLogic.laterDelay)
        save()
        update(now: now)
    }

    /// The X on an overdue task: it stays away until its due date changes (spec R-26).
    func dismissOverdue(_ item: ReminderItem, now: Date = Date()) {
        guard let due = item.due else { return }
        dismissed[item.id] = due.timeIntervalSince1970
        if dismissed.count > 200, let oldest = dismissed.min(by: { $0.value < $1.value }) { dismissed[oldest.key] = nil }
        save()
        update(now: now)
    }

    /// The task is shown in a thin row under the notch: its X and Later apply (spec R-26).
    func isOverdueNotice(_ item: ReminderItem) -> Bool {
        shown?.overdue.contains { $0.id == item.id } == true
    }

    func update(now: Date = Date()) {
        let items = openItems
        if let until = hiddenUntil,
           TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: hiddenIDs, openIDs: items.map(\.id), now: now) {
            hiddenUntil = nil
            hiddenIDs = []
            save()
        }
        let passed = later.filter { $0.value <= now }.map(\.key)
        if !passed.isEmpty {
            passed.forEach { later[$0] = nil }
            save()
        }
        let overdue = isEnabled
            ? TaskIndicatorLogic.overdueNotices(items, now: now, dismissed: dismissed, later: later) : []
        // The counter's × does not hide the overdue rows (spec R-26).
        var next = isEnabled && (hiddenUntil == nil || !overdue.isEmpty) ? TaskIndicatorLogic.count(items, now: now) : nil
        if next != nil {
            next?.tone = TaskIndicatorLogic.tone(items, now: now)
            next?.overdue = overdue
            let all = groups
            if all.count > 1 {
                next?.isSplit = true
                next?.listRows = (all.first { $0.listID == chosenListID } ?? TaskIndicatorLogic.defaultGroup(all))?.items.count
            }
        }
        if next != shown { shown = next }
        scheduleWake(at: TaskIndicatorLogic.nextChange(items, now: now, later: later, hiddenUntil: hiddenUntil))
    }

    private func save() {
        defaults.set(hiddenUntil, forKey: Key.hiddenUntil)
        defaults.set(Array(hiddenIDs), forKey: Key.hiddenIDs)
        defaults.set(dismissed, forKey: Key.dismissed)
        defaults.set(later, forKey: Key.later)
    }

    /// Looks again when the snooze ends, a due date passes or comes within the hour, or a Later
    /// is up, even if nothing else changes (spec R-11, R-26, R-27).
    private func scheduleWake(at moment: Date?) {
        guard moment != wakeAt else { return }
        wakeAt = moment
        wake?.cancel()
        guard let moment else { return }
        wake = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(moment.timeIntervalSinceNow, 0) + 1))
            guard !Task.isCancelled, let self else { return }
            self.wakeAt = nil
            self.update()
        }
    }
}
