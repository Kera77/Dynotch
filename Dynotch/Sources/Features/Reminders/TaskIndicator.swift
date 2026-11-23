import Combine
import Foundation

/// What the tasks counter beside the notch shows (spec R-10).
struct TaskCount: Equatable, Sendable {
    let count: Int
    /// Due today (or overdue); otherwise every open task.
    let isToday: Bool
    /// Rows under the drop-down's header: the chosen list's when the tasks are in several lists (spec R-17).
    var listRows: Int?
    /// The tasks are in several lists: the header chooses between them (spec R-17).
    var isSplit = false

    var rows: Int { listRows ?? count }

    var text: String {
        isToday ? "\(count) task\(count == 1 ? "" : "s") due today" : "\(count) open task\(count == 1 ? "" : "s")"
    }
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

    /// The counted tasks by list, in the lists' order (spec R-17).
    static func groups(_ listed: [ReminderItem], lists: [ReminderList]) -> [TaskGroup] {
        let byList = Dictionary(grouping: listed, by: \.listID)
        let known = lists.compactMap { list in
            byList[list.id].map { TaskGroup(listID: list.id, title: list.title, items: $0) }
        }
        let knownIDs = Set(lists.map(\.id))
        let others = listed.filter { !knownIDs.contains($0.listID) }
        return known + (others.isEmpty ? [] : [TaskGroup(listID: "", title: "Other", items: others)])
    }

    /// The list shown first: the one with the nearest due date (overdue too), else the first (spec R-17).
    static func defaultGroup(_ groups: [TaskGroup]) -> TaskGroup? {
        let dated = groups.compactMap { group in group.items.compactMap(\.due).min().map { (group, $0) } }
        return dated.min { $0.1 < $1.1 }?.0 ?? groups.first
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
final class TaskIndicator: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled); update() }
    }
    @Published var snooze: TaskSnooze {
        didSet { defaults.set(snooze.rawValue, forKey: Key.snooze) }
    }
    @Published private(set) var shown: TaskCount?
    /// The list chosen in the drop-down's header until it closes (spec R-17).
    @Published var chosenListID: String? {
        didSet { if chosenListID != oldValue { update() } }
    }

    private enum Key {
        static let enabled = "taskIndicator"
        static let snooze = "taskIndicatorSnooze"
        static let hiddenUntil = "taskIndicatorHiddenUntil"
        static let hiddenIDs = "taskIndicatorHiddenIDs"
    }

    private let store: RemindersStore
    private let defaults: UserDefaults
    private var hiddenUntil: Date?
    private var hiddenIDs: Set<String>
    private var changes: AnyCancellable?
    private var wake: Task<Void, Never>?

    init(store: RemindersStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Key.enabled) as? Bool ?? true
        snooze = (defaults.object(forKey: Key.snooze) as? Int).flatMap(TaskSnooze.init(rawValue:)) ?? .hour
        hiddenUntil = defaults.object(forKey: Key.hiddenUntil) as? Date
        hiddenIDs = Set(defaults.stringArray(forKey: Key.hiddenIDs) ?? [])
        // objectWillChange fires before the change: look once it has happened.
        changes = store.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        update()
        scheduleWake()
    }

    private var openItems: [ReminderItem] {
        store.access == .granted ? store.open.filter { !store.completing.contains($0.id) } : []
    }

    /// The tasks under the counter's hover drop-down (spec R-12).
    var listed: [ReminderItem] { TaskIndicatorLogic.listed(openItems, now: Date()) }

    /// The counted tasks by list (spec R-17).
    var groups: [TaskGroup] { TaskIndicatorLogic.groups(listed, lists: store.lists) }

    /// The list shown under the header: the chosen one, else the one due soonest (spec R-17).
    var selectedGroup: TaskGroup? {
        let all = groups
        return all.first { $0.listID == chosenListID } ?? TaskIndicatorLogic.defaultGroup(all)
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
        scheduleWake()
    }

    func update(now: Date = Date()) {
        let items = openItems
        if let until = hiddenUntil,
           TaskIndicatorLogic.showsAgain(hiddenUntil: until, hiddenIDs: hiddenIDs, openIDs: items.map(\.id), now: now) {
            hiddenUntil = nil
            hiddenIDs = []
            save()
        }
        var next = isEnabled && hiddenUntil == nil ? TaskIndicatorLogic.count(items, now: now) : nil
        if next != nil {
            let all = groups
            if all.count > 1 {
                next?.isSplit = true
                next?.listRows = (all.first { $0.listID == chosenListID } ?? TaskIndicatorLogic.defaultGroup(all))?.items.count
            }
        }
        if next != shown { shown = next }
    }

    private func save() {
        defaults.set(hiddenUntil, forKey: Key.hiddenUntil)
        defaults.set(Array(hiddenIDs), forKey: Key.hiddenIDs)
    }

    /// Shows the counter again when the snooze ends, even if nothing else changes.
    private func scheduleWake() {
        wake?.cancel()
        guard let until = hiddenUntil else { return }
        wake = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(until.timeIntervalSinceNow, 0) + 1))
            guard !Task.isCancelled else { return }
            self?.update()
        }
    }
}
